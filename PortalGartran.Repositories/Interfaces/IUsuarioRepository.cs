using PortalGartran.Core.Entities;

namespace PortalGartran.Repositories.Interfaces;

public interface IUsuarioRepository
{
    Task<Usuario?> GetByEmailAsync(string email);
    Task<Usuario?> GetByIdAsync(int id);
    Task CreateAsync(Usuario usuario);
    Task SaveChangesAsync();
}
