using PortalPCI.Core.Entities;

namespace PortalPCI.Repositories.Interfaces;

public interface IUsuarioRepository
{
    Task<Usuario?> GetByEmailAsync(string email);
    Task<Usuario?> GetByIdAsync(int id);
    Task CreateAsync(Usuario usuario);
    Task SaveChangesAsync();
}
