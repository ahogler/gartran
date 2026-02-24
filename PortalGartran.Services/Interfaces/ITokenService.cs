using PortalGartran.Core.Entities;

namespace PortalGartran.Services.Interfaces;

public interface ITokenService
{
    string GerarToken(Usuario usuario);
}
