using PortalPCI.Repositories.Interfaces;
using PortalPCI.Services.Interfaces;
using PortalPCI.Shared.DTOs;
using BCrypt.Net;

namespace PortalPCI.Services;

public class AuthService : IAuthService
{
    private readonly IUsuarioRepository _userRepository;
    private readonly ITokenService _tokenService;

    public AuthService(IUsuarioRepository userRepository, ITokenService tokenService)
    {
        _userRepository = userRepository;
        _tokenService = tokenService;
    }

    public async Task<LoginResponseDTO?> LoginAsync(LoginRequestDTO request)
    {
        if (string.IsNullOrWhiteSpace(request.Email) || string.IsNullOrWhiteSpace(request.Senha))
        {
            return null;
        }

        var usuario = await _userRepository.GetByEmailAsync(request.Email);

        if (usuario == null || !BCrypt.Net.BCrypt.Verify(request.Senha, usuario.PasswordHash))
        {
            return null;
        }

        var token = _tokenService.GerarToken(usuario);

        return new LoginResponseDTO
        {
            Token = token,
            Usuario = new UsuarioDTO
            {
                Id = usuario.Id,
                Email = usuario.Email,
                Nome = usuario.Nome,
                Role = usuario.Role.ToString(),
                CriadoEm = usuario.CriadoEm
            }
        };
    }
}
