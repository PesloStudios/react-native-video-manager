
package com.lklima.video.manager;

import com.coremedia.iso.boxes.Container;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Promise;

import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.util.Log;
import com.facebook.react.bridge.ReadableArray;

import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.ReadableNativeMap;
import com.facebook.react.bridge.WritableMap;
import com.facebook.react.bridge.WritableNativeMap;
import com.googlecode.mp4parser.authoring.Movie;
import com.googlecode.mp4parser.authoring.Track;
import com.googlecode.mp4parser.authoring.container.mp4.MovieCreator;
import com.googlecode.mp4parser.authoring.tracks.AppendTrack;
import com.googlecode.mp4parser.authoring.builder.DefaultMp4Builder;

import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.RandomAccessFile;
import java.net.URI;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

public class RNVideoManagerModule extends ReactContextBaseJavaModule {

  private final ReactApplicationContext reactContext;

  public RNVideoManagerModule(ReactApplicationContext reactContext) {
    super(reactContext);
    this.reactContext = reactContext;
  }

  @ReactMethod
  public void getVideoMetadataFor(ReadableArray fileNames, Promise promise) {
    try {
      WritableMap metadata = new WritableNativeMap();

      for (int i = 0; i < fileNames.size(); i++) {
        String fileName = fileNames.getString(i);
        MediaMetadataRetriever retriever = new MediaMetadataRetriever();
        retriever.setDataSource(reactContext.getApplicationContext(), Uri.parse(fileName.replaceFirst("file://", "")));
        String time = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION);

        if (time == null) {
          time = "-1000";
        }

        int seconds = (int) (Long.parseLong(time) / 1000);

        WritableMap fileMetadata = new WritableNativeMap();
        fileMetadata.putInt("duration", seconds);
        fileMetadata.putBoolean("playable", true);

        metadata.putMap(fileName, fileMetadata);
      }

      promise.resolve(metadata);
    } catch (IOException e) {
      throw new RuntimeException(e);
    } catch (Error e) {
      e.printStackTrace();
      promise.reject(e.getMessage());
    }
  }

  @ReactMethod
  public void generateThumbnailFor(String video, ReadableMap options, Promise promise) {
    String writeDirectory = options.getString("writeDirectory");
    String fileName = options.getString("fileName");
    long timestamp = (long) options.getDouble("timestamp");

    String filePath = String.format("%s/%s.png", writeDirectory, fileName);

    try {
      MediaMetadataRetriever retriever = new MediaMetadataRetriever();
      Bitmap thumbnailBitmap = null;

      retriever.setDataSource(reactContext.getApplicationContext(), Uri.parse(video.replaceFirst("file://", "")));

      thumbnailBitmap = retriever.getFrameAtTime(timestamp * 1000000, MediaMetadataRetriever.OPTION_CLOSEST_SYNC);

      try (FileOutputStream out = new FileOutputStream(filePath)) {
        thumbnailBitmap.compress(Bitmap.CompressFormat.PNG, 100, out);
      } catch (IOException e) {
        e.printStackTrace();
      }

      promise.resolve(true);
    } catch (Error e) {
      e.printStackTrace();
      promise.reject(e.getMessage());
    }
  }

  @ReactMethod
  public void merge(ReadableArray videoFiles, Promise promise) {

    List<Movie> inMovies = new ArrayList<Movie>();

    for (int i = 0; i < videoFiles.size(); i++) {
     String videoUrl = videoFiles.getString(i).replaceFirst("file://", "");

      try {
        inMovies.add(MovieCreator.build(videoUrl));
      } catch (IOException e) {
        promise.reject(e.getMessage());
        e.printStackTrace();
      }
    }

    List<Track> videoTracks = new LinkedList<Track>();
    List<Track> audioTracks = new LinkedList<Track>();

    for (Movie m : inMovies) {
      for (Track t : m.getTracks()) {
        if (t.getHandler().equals("soun")) {
          audioTracks.add(t);
        }
        if (t.getHandler().equals("vide")) {
          videoTracks.add(t);
        }
      }
    }

    Movie result = new Movie();

    if (!audioTracks.isEmpty()) {
      try {
        result.addTrack(new AppendTrack(audioTracks.toArray(new Track[audioTracks.size()])));
      } catch (IOException e) {
        promise.reject(e.getMessage());
        e.printStackTrace();
      }
    }
    if (!videoTracks.isEmpty()) {
      try {
        result.addTrack(new AppendTrack(videoTracks.toArray(new Track[videoTracks.size()])));
      } catch (IOException e) {
        promise.reject(e.getMessage());
        e.printStackTrace();
      }
    }

    Container out = new DefaultMp4Builder().build(result);
    FileChannel fc = null;

    try {

      Long tsLong = System.currentTimeMillis()/1000;
      String ts = tsLong.toString();

      String outputVideo = reactContext.getApplicationContext().getCacheDir().getAbsolutePath()+"output_"+ts+".mp4";

      fc = new RandomAccessFile(String.format(outputVideo), "rw").getChannel();

      Log.d("VIDEO", String.valueOf(fc));
      out.writeContainer(fc);
      fc.close();
      promise.resolve(outputVideo);
    } catch (FileNotFoundException e) {
      e.printStackTrace();
      promise.reject(e.getMessage());
    } catch (IOException e) {
      e.printStackTrace();
      promise.reject(e.getMessage());
    }

  }

  @Override
  public String getName() {
    return "RNVideoManager";
  }
}
