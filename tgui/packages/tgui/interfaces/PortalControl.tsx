// tgui/packages/tgui/interfaces/PortalControl.tsx

import {
  Box,
  Button,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

interface PortalControlData {
  portal_present: boolean;
  portal_status: boolean;
  portal_active: boolean;
  current_target?: {
    name: string;
    key: string;
    description?: string;
  };
  destinations: Array<{
    name: string;
    description: string;
    key: string;
    available: boolean;
    available_reason: string;
    timeout?: number;
    connected?: boolean;
  }>;
  generation_status: string;
  generation_progress: number;
  generation_cooldown: number;
  generate_cooldown: number;
  can_generate: boolean;
  generation_in_progress: boolean;
  portal_data?: {
    map_name?: string;
    technical_name?: string;
  };
}

export const PortalControl = (props, context) => {
  const { act, data } = useBackend<PortalControlData>(context);

  const {
    portal_present,
    portal_status,
    portal_active,
    current_target,
    destinations,
    generation_status,
    generation_progress,
    generation_cooldown,
    generate_cooldown,
    can_generate,
    generation_in_progress,
    portal_data,
  } = data;

  const getGenerationColor = () => {
    switch (generation_status) {
      case 'generating':
        return 'good';
      case 'ready':
        return 'blue';
      case 'error':
        return 'bad';
      default:
        return 'grey';
    }
  };

  const getGenerationText = () => {
    switch (generation_status) {
      case 'generating':
        return `Stabilizing Portal... ${Math.round(generation_progress)}%`;
      case 'ready':
        return 'Portal Stabilized';
      case 'error':
        return 'Destabilization Error';
      default:
        return 'Idle';
    }
  };

  const getGenerateTooltip = () => {
    if (!can_generate) {
      if (generation_in_progress) {
        return 'Portal stabilization in progress...';
      }
      if (generation_cooldown > 0) {
        return `Cooldown: ${Math.round(generation_cooldown)}s remaining`;
      }
      return 'Cannot generate at this time';
    }
    return 'Generate new portal destination';
  };

  return (
    <Window width={500} height={500} theme="admin">
      <Window.Content scrollable>
        <Section title="Portal Control Console">
          <LabeledList>
            <LabeledList.Item label="Portal Linked">
              <Box color={portal_present ? 'good' : 'bad'}>
                {portal_present ? 'Connected' : 'Not Found'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Portal Power">
              <Box color={portal_status ? 'good' : 'bad'}>
                {portal_status ? 'Powered' : 'No Power'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Portal Active">
              <Box color={portal_active ? 'good' : 'bad'}>
                {portal_active ? 'Active' : 'Inactive'}
              </Box>
            </LabeledList.Item>
            {current_target && (
              <LabeledList.Item label="Current Destination">
                <Box color="blue">{current_target.name}</Box>
              </LabeledList.Item>
            )}
          </LabeledList>

          {!portal_present && (
            <Box mt={1}>
              <Button icon="link" onClick={() => act('linkup')}>
                Scan for Portal
              </Button>
            </Box>
          )}
        </Section>

        <Section title="Portal Generation">
          <Stack vertical>
            <Stack.Item>
              <ProgressBar
                value={generation_progress / 100}
                color={getGenerationColor()}
                minValue={0}
                maxValue={1}
              >
                {getGenerationText()}
              </ProgressBar>
            </Stack.Item>

            <Stack.Item>
              <Button
                icon="bolt"
                fluid
                disabled={!can_generate}
                tooltip={getGenerateTooltip()}
                onClick={() => act('generate_new')}
              >
                Generate New Portal
              </Button>
            </Stack.Item>

            {generation_cooldown > 0 && (
              <Stack.Item>
                <Box textAlign="center" color="average">
                  Cooldown: {Math.round(generation_cooldown)} /{' '}
                  {generate_cooldown} seconds
                </Box>
              </Stack.Item>
            )}

            {portal_data && portal_data.map_name && (
              <Stack.Item>
                <Section title="Active Portal Destination">
                  <LabeledList>
                    <LabeledList.Item label="Destination">
                      {portal_data.map_name}
                    </LabeledList.Item>
                    {portal_data.technical_name && (
                      <LabeledList.Item label="Coordinates">
                        {portal_data.technical_name}
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Section>
              </Stack.Item>
            )}
          </Stack>
        </Section>

        {current_target && (
          <Section title="Active Connection">
            <Button
              icon="power-off"
              fluid
              color="bad"
              onClick={() => act('deactivate')}
            >
              Deactivate Portal
            </Button>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
