using PortalGartran.Core.Enums;

namespace PortalGartran.Core.Entities;

public class Usuario
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public RoleEnum Role { get; set; } = RoleEnum.Usuario;
    public DateTime CriadoEm { get; set; } = DateTime.UtcNow;
    public DateTime? AtualizadoEm { get; set; }
}
