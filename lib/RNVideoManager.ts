import { NativeModules } from "react-native";

const { RNVideoManager } = NativeModules;

interface MergeResponse {
  uri: string;
  duration: number;
}

interface DurationResponse {
  duration: number;
}

interface Options {
  writeDirectory?: string;
  fileName?: string;
  ignoreSound?: boolean
  actionKey?: string;
}

export async function merge(videos: string[], options?: Options): Promise<MergeResponse> {
  const {uri, duration}: { uri: string, duration: number } = await RNVideoManager.merge(videos, options);

  return { uri, duration };
}

export async function getTotalDurationFor(video: string): Promise<DurationResponse> {
  const { duration }: DurationResponse = await RNVideoManager.getTotalDurationFor(video);

  return { duration }
}
