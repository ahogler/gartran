using Microsoft.EntityFrameworkCore;
using PortalGartran.Core.Entities;
using PortalGartran.Core.Enums;

namespace PortalGartran.Repositories.Data;

public class AppDbContext : DbContext
{
    public AppDbContext(DbContextOptions<AppDbContext> options) : base(options) { }

    public DbSet<Usuario> Usuarios { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        var adminPasswordHash = BCrypt.Net.BCrypt.HashPassword("admin123");

        modelBuilder.Entity<Usuario>().HasData(
            new Usuario
            {
                Id = 1,
                Email = "admin@gartan.com.br",
                Nome = "Administrador",
                PasswordHash = adminPasswordHash,
                Role = RoleEnum.Admin,
                CriadoEm = DateTime.UtcNow
            }
        );

        modelBuilder.Entity<Usuario>()
            .HasIndex(u => u.Email)
            .IsUnique();
    }
}
