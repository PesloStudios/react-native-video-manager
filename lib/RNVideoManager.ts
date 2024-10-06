import { NativeModules, Platform } from "react-native";

const { RNVideoManager } = NativeModules;

interface MergeResponse {
  uri: string;
  duration: number;
}

interface GridExportResponse {
  uri: string;
}

interface DurationResponse {
  duration: number;
  playable: boolean;
}

type MetadataResponse = Record<string, DurationResponse>

interface ThumbnailResponse {
  uri: string
}

interface MergeOptions {
  writeDirectory?: string;
  fileName?: string;
  ignoreSound?: boolean
}

export type GridExportResolutionOption = "720p" | "1080p" | "4K" | "doubleLargest"

interface GridExportOptions {
  writeDirectory: string;
  fileName: string;
  duration: number;
  resolution: GridExportResolutionOption
}

interface ThumbnailOptions {
  writeDirectory: string;
  fileName: string;
  timestamp: number;
}

// TODO: Update this to use properties on Android / match iOS functionality
export async function merge(videos: string[], options?: MergeOptions): Promise<MergeResponse> {
  const {uri, duration}: { uri: string, duration: number } = await RNVideoManager.merge(videos, options);

  return { uri, duration };
}

// TODO: Update this to also work on Android
export async function exportAsGrid(videos: string[], options?: GridExportOptions): Promise<GridExportResponse | null> {
  if (Platform.OS === 'android') {
    return null
  }
  
  const {uri}: { uri: string } = await RNVideoManager.exportAsGrid(videos, options);

  return { uri };
}

export async function getDurationFor(video: string): Promise<DurationResponse> {
  const { duration, playable }: DurationResponse = await RNVideoManager.getDurationFor(video);

  return { duration, playable }
}

// TODO: Test how Android handles corrupted video files
export async function getVideoMetadataFor(videos: string[]): Promise<MetadataResponse> {
  const result: MetadataResponse = await RNVideoManager.getVideoMetadataFor(videos);

  return result
}

// TODO: native module function resolves with a boolean if it's worked
export async function generateThumbnailFor(video: string, options: ThumbnailOptions): Promise<ThumbnailResponse> {
  const { uri }: ThumbnailResponse = await RNVideoManager.generateThumbnailFor(video, options);

  return { uri }
}