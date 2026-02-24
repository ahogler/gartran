using PortalPCI.Shared.DTOs;

namespace PortalPCI.Services.Interfaces;

public interface IAuthService
{
    Task<LoginResponseDTO?> LoginAsync(LoginRequestDTO request);
}
