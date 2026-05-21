namespace ListaDeTareasApp
{
    public partial class AppShell : Shell
    {
        public AppShell()
        {
            InitializeComponent();
            Routing.RegisterRoute(nameof(TareaPage), typeof(TareaPage));
        }
    }
}
