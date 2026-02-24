namespace PortalPCI.Shared.DTOs;

public class LoginResponseDTO
{
    public string Token { get; set; } = string.Empty;
    public UsuarioDTO Usuario { get; set; } = new();
}
