using PortalGartran.Shared.DTOs;

namespace PortalGartran.Services.Interfaces;

public interface IAuthService
{
    Task<LoginResponseDTO?> LoginAsync(LoginRequestDTO request);
}
