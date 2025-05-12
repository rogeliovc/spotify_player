package com.yourpackage;

import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.TextView;
import androidx.recyclerview.widget.RecyclerView;
import java.util.List;

public class PlaylistAdapter extends RecyclerView.Adapter<PlaylistAdapter.ViewHolder> {
    private final List<Playlist> playlists;

    public PlaylistAdapter(List<Playlist> playlists) {
        this.playlists = playlists;
    }

    @Override
    public ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        View view = LayoutInflater.from(parent.getContext())
            .inflate(R.layout.item_playlist, parent, false);
        return new ViewHolder(view);
    }

    @Override
    public void onBindViewHolder(ViewHolder holder, int position) {
        Playlist playlist = playlists.get(position);
        holder.image.setImageResource(playlist.imageRes);
        holder.title.setText(playlist.title);
    }

    @Override
    public int getItemCount() {
        return playlists.size();
    }

    static class ViewHolder extends RecyclerView.ViewHolder {
        ImageView image;
        TextView title;
        ViewHolder(View itemView) {
            super(itemView);
            image = itemView.findViewById(R.id.playlist_image);
            title = itemView.findViewById(R.id.playlist_title);
        }
    }
}
