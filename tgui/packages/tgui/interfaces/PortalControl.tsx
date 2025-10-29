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
  dungeon_data?: {
    map_name?: string;
    z_level?: number;
    technical_name?: string;
    seed?: number;
    dimensions?: {
      width: number;
      height: number;
    };
    statistics?: {
      rooms?: number;
      mobs?: number;
    };
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

  const getDestinationTooltip = (destination: (typeof destinations)[0]) => {
    if (!destination.available) {
      return destination.available_reason;
    }
    if (portal_active) {
      return 'Deactivate current portal first';
    }
    return `Activate portal to ${destination.name}`;
  };

  return (
    <Window width={500} height={600} theme="admin">
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
              <LabeledList.Item label="Current Target">
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

        <Section title="Dungeon Generation">
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
                Generate New Dungeon
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

            {dungeon_data && (
              <Stack.Item>
                <Section title="Current Dungeon">
                  <LabeledList>
                    <LabeledList.Item label="Name">
                      {dungeon_data.map_name || 'Unknown Dungeon'}
                    </LabeledList.Item>
                    <LabeledList.Item label="Z-Level">
                      {dungeon_data.z_level || 'Not loaded'}
                    </LabeledList.Item>
                    {dungeon_data.dimensions && (
                      <LabeledList.Item label="Size">
                        {dungeon_data.dimensions.width} ×{' '}
                        {dungeon_data.dimensions.height}
                      </LabeledList.Item>
                    )}
                    {dungeon_data.statistics && (
                      <>
                        {dungeon_data.statistics.rooms && (
                          <LabeledList.Item label="Rooms">
                            {dungeon_data.statistics.rooms}
                          </LabeledList.Item>
                        )}
                        {dungeon_data.statistics.mobs && (
                          <LabeledList.Item label="Threats">
                            {dungeon_data.statistics.mobs}
                          </LabeledList.Item>
                        )}
                      </>
                    )}
                    {dungeon_data.seed && (
                      <LabeledList.Item label="Seed">
                        {dungeon_data.seed}
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Section>
              </Stack.Item>
            )}
          </Stack>
        </Section>

        <Section title="Available Destinations">
          {destinations.length === 0 ? (
            <Box color="label" textAlign="center">
              No destinations available
            </Box>
          ) : (
            destinations.map((destination) => (
              <Box
                key={destination.key}
                mb={1}
                p={1}
                backgroundColor="rgba(0,0,0,0.1)"
                style={{
                  border:
                    current_target?.key === destination.key
                      ? '2px solid #00ff00'
                      : '1px solid #555',
                }}
              >
                <Stack align="center">
                  <Stack.Item grow>
                    <Box>
                      <Stack vertical>
                        <Stack.Item>
                          <Box
                            bold
                            color={
                              current_target?.key === destination.key
                                ? 'good'
                                : destination.available
                                  ? 'white'
                                  : 'gray'
                            }
                          >
                            {destination.name}
                          </Box>
                        </Stack.Item>
                        <Stack.Item>
                          <Box color="label">{destination.description}</Box>
                        </Stack.Item>
                        {!destination.available && (
                          <Stack.Item>
                            <Box color="average" mt={0.5}>
                              {destination.available_reason}
                            </Box>
                          </Stack.Item>
                        )}
                        {destination.timeout !== undefined &&
                          destination.timeout > 0 && (
                            <Stack.Item>
                              <ProgressBar
                                value={destination.timeout}
                                minValue={0}
                                maxValue={1}
                                color="blue"
                                mt={0.5}
                              >
                                Calibrating...
                              </ProgressBar>
                            </Stack.Item>
                          )}
                      </Stack>
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
                      tooltip={getDestinationTooltip(destination)}
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
