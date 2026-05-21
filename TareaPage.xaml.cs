using ListaDeTareasApp.Models;
using ListaDeTareasApp.Services;

namespace ListaDeTareasApp
{
    [QueryProperty(nameof(TareaId), "id")]
    public partial class TareaPage : ContentPage
    {
        private readonly TareaDatabase database = new();
        private Tarea tarea = new();

        public string TareaId
        {
            set
            {
                if (int.TryParse(value, out var id))
                {
                    _ = CargarTareaAsync(id);
                }
            }
        }

        public TareaPage()
        {
            InitializeComponent();
            EliminarButton.IsVisible = false;
        }

        private async Task CargarTareaAsync(int id)
        {
            try
            {
                var tareaGuardada = await database.GetTareaAsync(id);

                if (tareaGuardada is null)
                {
                    await DisplayAlertAsync("Aviso", "La tarea seleccionada no existe.", "Aceptar");
                    await Shell.Current.GoToAsync("..");
                    return;
                }

                tarea = tareaGuardada;
                NombreEntry.Text = tarea.Nombre;
                DescripcionEditor.Text = tarea.Descripcion;
                EliminarButton.IsVisible = true;
            }
            catch (Exception ex)
            {
                await DisplayAlertAsync("Error", $"No se pudo cargar la tarea: {ex.Message}", "Aceptar");
                await Shell.Current.GoToAsync("..");
            }
        }

        private async void OnGuardarClicked(object? sender, EventArgs e)
        {
            var nombre = NombreEntry.Text?.Trim() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(nombre))
            {
                await DisplayAlertAsync("Validacion", "El nombre de la tarea es obligatorio.", "Aceptar");
                return;
            }

            try
            {
                tarea.Nombre = nombre;
                tarea.Descripcion = DescripcionEditor.Text?.Trim() ?? string.Empty;

                await database.SaveTareaAsync(tarea);
                await Shell.Current.GoToAsync("..");
            }
            catch (Exception ex)
            {
                await DisplayAlertAsync("Error", $"No se pudo guardar la tarea: {ex.Message}", "Aceptar");
            }
        }

        private async void OnEliminarClicked(object? sender, EventArgs e)
        {
            var confirmar = await DisplayAlertAsync("Eliminar tarea", "Deseas eliminar esta tarea?", "Si", "No");

            if (!confirmar)
            {
                return;
            }

            try
            {
                await database.DeleteTareaAsync(tarea);
                await Shell.Current.GoToAsync("..");
            }
            catch (Exception ex)
            {
                await DisplayAlertAsync("Error", $"No se pudo eliminar la tarea: {ex.Message}", "Aceptar");
            }
        }
    }
}
