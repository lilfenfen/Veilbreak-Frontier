import { Feature, FeatureColorInput } from '../../base';

// For the Void-Touched quirk's space texture color.
export const void_touched_color: Feature<string> = {
  name: 'Void-Touched Color',
  component: FeatureColorInput,
};
