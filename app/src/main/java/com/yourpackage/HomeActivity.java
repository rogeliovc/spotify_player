package com.yourpackage;

import android.os.Bundle;
import android.widget.CalendarView;
import android.widget.Toast;
import androidx.appcompat.app.AppCompatActivity;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import java.util.Arrays;
import java.util.List;

public class HomeActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_home);

        RecyclerView playlistRecycler = findViewById(R.id.playlistRecycler);
        playlistRecycler.setLayoutManager(
            new LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false));
        playlistRecycler.setAdapter(new PlaylistAdapter(getPlaylists()));

        RecyclerView taskRecycler = findViewById(R.id.taskRecycler);
        taskRecycler.setLayoutManager(
            new LinearLayoutManager(this, LinearLayoutManager.HORIZONTAL, false));
        taskRecycler.setAdapter(new TaskAdapter(getTasks()));

        CalendarView calendarView = findViewById(R.id.calendarView);
        calendarView.setOnDateChangeListener(new CalendarView.OnDateChangeListener() {
            @Override
            public void onSelectedDayChange(CalendarView view, int year, int month, int dayOfMonth) {
                // Ejemplo: mostrar la fecha seleccionada
                String date = dayOfMonth + "/" + (month + 1) + "/" + year;
                Toast.makeText(HomeActivity.this, "Seleccionaste: " + date, Toast.LENGTH_SHORT).show();
                // Aquí puedes filtrar las tareas por fecha si lo deseas
            }
        });
    }

    private List<Playlist> getPlaylists() {
        // Simula datos
        return Arrays.asList(
            new Playlist("Alternativa", R.drawable.playlist1),
            new Playlist("Pop - Rock", R.drawable.playlist2),
            new Playlist("Folk", R.drawable.playlist3),
            new Playlist("Balada", R.drawable.playlist4)
        );
    }

    private List<Task> getTasks() {
        // Simula datos
        return Arrays.asList(
            new Task("Maquetado", "Urgente", "Sincronía", "01/04/2025", R.drawable.task1),
            new Task("Diseño de menú", "Urgente", "Sincronía", "04/04/2025", R.drawable.task2),
            new Task("Configuración", "On Time", "Sincronía", "10/04/2025", R.drawable.task3)
        );
    }
}
