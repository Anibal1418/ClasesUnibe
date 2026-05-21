using ListaDeTareasApp.Models;
using SQLite;

namespace ListaDeTareasApp.Services
{
    public class TareaDatabase
    {
        private SQLiteAsyncConnection? database;

        private async Task InitAsync()
        {
            if (database is not null)
            {
                return;
            }

            var databasePath = Path.Combine(FileSystem.AppDataDirectory, "tareas.db3");
            database = new SQLiteAsyncConnection(databasePath);
            await database.CreateTableAsync<Tarea>();
        }

        public async Task<List<Tarea>> GetTareasAsync()
        {
            await InitAsync();
            return await database!.Table<Tarea>().OrderBy(tarea => tarea.Nombre).ToListAsync();
        }

        public async Task<Tarea?> GetTareaAsync(int id)
        {
            await InitAsync();
            return await database!.Table<Tarea>().Where(tarea => tarea.Id == id).FirstOrDefaultAsync();
        }

        public async Task<int> SaveTareaAsync(Tarea tarea)
        {
            await InitAsync();

            if (tarea.Id == 0)
            {
                return await database!.InsertAsync(tarea);
            }

            return await database!.UpdateAsync(tarea);
        }

        public async Task<int> DeleteTareaAsync(Tarea tarea)
        {
            await InitAsync();
            return await database!.DeleteAsync(tarea);
        }
    }
}
