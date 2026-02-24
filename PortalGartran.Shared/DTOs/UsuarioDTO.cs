namespace PortalGartran.Shared.DTOs;

public class UsuarioDTO
{
    public int Id { get; set; }
    public string Email { get; set; } = string.Empty;
    public string Nome { get; set; } = string.Empty;
    public string Role { get; set; } = string.Empty;
    public DateTime CriadoEm { get; set; }
}
