using PortalPCI.Core.Entities;

namespace PortalPCI.Services.Interfaces;

public interface ITokenService
{
    string GerarToken(Usuario usuario);
}
