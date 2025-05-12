package com.yourpackage;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import java.util.List;

public class TaskAdapter extends RecyclerView.Adapter<TaskAdapter.ViewHolder> {
    private final List<Task> tasks;

    public TaskAdapter(List<Task> tasks) {
        this.tasks = tasks;
    }

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
            .inflate(R.layout.item_task, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        Task task = tasks.get(position);
        holder.image.setImageResource(task.imageRes);
        holder.title.setText(task.title);
        holder.subtitle.setText(task.subtitle);
        holder.project.setText(task.project);
        holder.date.setText("Fecha: " + task.date);
    }

    @Override
    public int getItemCount() {
        return tasks.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        ImageView image;
        TextView title, subtitle, project, date;
        ViewHolder(View itemView) {
            super(itemView);
            image = itemView.findViewById(R.id.task_image);
            title = itemView.findViewById(R.id.task_title);
            subtitle = itemView.findViewById(R.id.task_subtitle);
            project = itemView.findViewById(R.id.task_project);
            date = itemView.findViewById(R.id.task_date);
        }
    }
}
