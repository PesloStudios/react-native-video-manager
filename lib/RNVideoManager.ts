import { NativeModules } from "react-native";

const { RNVideoManager } = NativeModules;

interface MergeResponse {
  uri: string;
  duration: number;
}

interface DurationResponse {
  duration: number;
}

interface ThumbnailResponse {
  uri: string
}

interface MergeOptions {
  writeDirectory?: string;
  fileName?: string;
  ignoreSound?: boolean
  actionKey?: string;
}

interface ThumbnailOptions {
  writeDirectory: string;
  fileName: string;
  timestamp: number;
}

export async function merge(videos: string[], options?: MergeOptions): Promise<MergeResponse> {
  const {uri, duration}: { uri: string, duration: number } = await RNVideoManager.merge(videos, options);

  return { uri, duration };
}

export async function getDurationOf(video: string): Promise<DurationResponse> {
  const { duration }: DurationResponse = await RNVideoManager.getDurationOf(video);

  return { duration }
}

export async function generateThumbnailFor(video: string, options: ThumbnailOptions): Promise<ThumbnailResponse> {
  const { uri }: ThumbnailResponse = await RNVideoManager.generateThumbnailFor(video, options);

  return { uri }
}