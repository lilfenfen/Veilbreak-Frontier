// modular_zzveilbreak/code/modules/dungeons/portal_control.tsx

import { useBackend } from '../backend';
import {
  Box,
  Button,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
} from '../components';
import { Window } from '../layouts';

interface PortalControlData {
  portal_present: boolean;
  portal_status: boolean;
  portal_active: boolean;
  current_target?: {
    name: string;
    key: string;
  };
  destinations: Array<{
    name: string;
    description: string;
    key: string;
    available: boolean;
    available_reason: string;
  }>;
  generation_status: string;
  generation_progress: number;
  generation_cooldown: number;
  generate_cooldown: number;
  can_generate: boolean;
  generation_in_progress: boolean;
  dungeon_data?: {
    map_name: string;
    z_level: number;
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
    dungeon_data,
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
        return `Generating... ${Math.round(generation_progress)}%`;
      case 'ready':
        return 'Ready';
      case 'error':
        return 'Error';
      default:
        return 'Idle';
    }
  };

  const getGenerateTooltip = () => {
    if (!can_generate) {
      if (generation_in_progress) {
        return 'Generation in progress...';
      }
      if (generation_cooldown > 0) {
        return `Cooldown: ${Math.round(generation_cooldown)}s remaining`;
      }
      return 'Cannot generate at this time';
    }
    return 'Generate new dungeon';
  };

  return (
    <Window width={500} height={600} theme="admin">
      <Window.Content scrollable>
        <Section title="Portal Status">
          <LabeledList>
            <LabeledList.Item label="Portal Linked">
              {portal_present ? 'Connected' : 'Not Found'}
            </LabeledList.Item>
            <LabeledList.Item label="Portal Power">
              {portal_status ? 'Powered' : 'No Power'}
            </LabeledList.Item>
            <LabeledList.Item label="Portal Active">
              {portal_active ? 'Active' : 'Inactive'}
            </LabeledList.Item>
            {current_target && (
              <LabeledList.Item label="Current Target">
                {current_target.name}
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

        <Section title="Dungeon Generation">
          <Stack vertical>
            <Stack.Item>
              <ProgressBar
                value={generation_progress / 100}
                color={getGenerationColor()}
              >
                {getGenerationText()}
              </ProgressBar>
            </Stack.Item>

            <Stack.Item>
              <Button
                icon="bolt"
                disabled={!can_generate}
                tooltip={getGenerateTooltip()}
                onClick={() => act('generate_new')}
              >
                Generate New Dungeon
              </Button>
            </Stack.Item>

            {generation_cooldown > 0 && (
              <Stack.Item>
                <Box color="average">
                  Cooldown: {Math.round(generation_cooldown)} /{' '}
                  {generate_cooldown} seconds
                </Box>
              </Stack.Item>
            )}

            {dungeon_data && (
              <Stack.Item>
                <Box mt={1} p={1} backgroundColor="rgba(0,0,0,0.2)">
                  <strong>Current Dungeon:</strong>{' '}
                  {dungeon_data.map_name || 'Unknown'}
                  <br />
                  <small>Z-Level: {dungeon_data.z_level || 'Not loaded'}</small>
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Section>

        <Section title="Available Destinations">
          {destinations.length === 0 ? (
            <Box color="label">No destinations available</Box>
          ) : (
            destinations.map((destination) => (
              <Box
                key={destination.key}
                mb={1}
                p={1}
                backgroundColor="rgba(0,0,0,0.1)"
              >
                <Stack align="center">
                  <Stack.Item grow>
                    <Box>
                      <strong>{destination.name}</strong>
                      <br />
                      <small>{destination.description}</small>
                      {!destination.available && (
                        <Box color="average">
                          {destination.available_reason}
                        </Box>
                      )}
                    </Box>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      icon="power-off"
                      color={
                        current_target?.key === destination.key
                          ? 'good'
                          : 'default'
                      }
                      disabled={!destination.available || portal_active}
                      tooltip={
                        !destination.available
                          ? destination.available_reason
                          : portal_active
                            ? 'Deactivate current portal first'
                            : `Activate portal to ${destination.name}`
                      }
                      onClick={() =>
                        act('activate', {
                          destination: destination.key,
                        })
                      }
                    >
                      {current_target?.key === destination.key
                        ? 'Active'
                        : 'Activate'}
                    </Button>
                  </Stack.Item>
                </Stack>
              </Box>
            ))
          )}
        </Section>

        {current_target && (
          <Section title="Current Connection">
            <Button
              icon="power-off"
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
