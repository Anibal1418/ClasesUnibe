using ListaDeTareasApp.Models;
using ListaDeTareasApp.Services;

namespace ListaDeTareasApp
{
    public partial class MainPage : ContentPage
    {
        private readonly TareaDatabase database = new();

        public MainPage()
        {
            InitializeComponent();
        }

        protected override async void OnAppearing()
        {
            base.OnAppearing();
            await CargarTareasAsync();
        }

        private async Task CargarTareasAsync()
        {
            try
            {
                TareasCollectionView.ItemsSource = await database.GetTareasAsync();
            }
            catch (Exception ex)
            {
                await DisplayAlertAsync("Error", $"No se pudieron cargar las tareas: {ex.Message}", "Aceptar");
            }
        }

        private async void OnAgregarTareaClicked(object? sender, EventArgs e)
        {
            await Shell.Current.GoToAsync(nameof(TareaPage));
        }

        private async void OnTareaSeleccionada(object? sender, SelectionChangedEventArgs e)
        {
            if (e.CurrentSelection.FirstOrDefault() is not Tarea tarea)
            {
                return;
            }

            TareasCollectionView.SelectedItem = null;
            await Shell.Current.GoToAsync($"{nameof(TareaPage)}?id={tarea.Id}");
        }
    }
}
