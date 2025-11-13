// tgui/packages/tgui/interfaces/PortalControl.tsx

import {
  Box,
  Button,
  Icon,
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
  };
  generation_status: string;
  generation_progress: number;
  can_generate: boolean;
  generation_in_progress: boolean;
  portal_name?: string;
}

export const PortalControl = (props, context) => {
  const { act, data } = useBackend<PortalControlData>(context);

  const {
    portal_present,
    portal_status,
    portal_active,
    current_target,
    generation_status,
    generation_progress,
    can_generate,
    generation_in_progress,
    portal_name,
  } = data;

  // Status indicators with icons
  const getPortalStatus = () => {
    if (!portal_present) {
      return { color: 'bad', icon: 'unlink', text: 'No Portal Linked' };
    }
    if (!portal_status) {
      return { color: 'bad', icon: 'bolt', text: 'No Power' };
    }
    if (portal_active) {
      return { color: 'good', icon: 'portal', text: 'Active' };
    }
    if (generation_in_progress) {
      return { color: 'average', icon: 'cog', text: 'Stabilizing...' };
    }
    return { color: 'blue', icon: 'check', text: 'Ready' };
  };

  const status = getPortalStatus();

  return (
    <Window width={480} height={420}>
      <Window.Content>
        <Stack vertical fill>
          {/* Header Status Panel */}
          <Stack.Item>
            <Section
              title="Dimensional Portal Control"
              buttons={
                <Button
                  icon="sync"
                  tooltip="Rescan for portal"
                  onClick={() => act('linkup')}
                >
                  Rescan
                </Button>
              }
            >
              <Stack>
                <Stack.Item grow>
                  <LabeledList>
                    <LabeledList.Item label="System Status">
                      <Box color={status.color} bold>
                        <Icon name={status.icon} mr={1} />
                        {status.text}
                      </Box>
                    </LabeledList.Item>
                    {portal_name && (
                      <LabeledList.Item label="Destination">
                        <Box color="violet" bold>
                          {portal_name}
                        </Box>
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Main Control Panel */}
          <Stack.Item grow>
            <Section
              title="Portal Operations"
              fill
              buttons={
                portal_active && (
                  <Button
                    icon="power-off"
                    color="bad"
                    onClick={() => act('deactivate')}
                  >
                    Emergency Shutdown
                  </Button>
                )
              }
            >
              <Stack vertical fill align="center" justify="center">
                {/* Generation Progress */}
                {generation_in_progress && (
                  <Stack.Item width="100%">
                    <Box textAlign="center" mb={2}>
                      <Icon name="cog" spin mr={1} />
                      <strong>Stabilizing Portal Matrix</strong>
                    </Box>
                    <ProgressBar
                      value={generation_progress / 100}
                      color="good"
                      ranges={{
                        good: [0.75, 1],
                        average: [0.25, 0.75],
                        bad: [0, 0.25],
                      }}
                    >
                      {generation_progress}% Complete
                    </ProgressBar>
                    <Box textAlign="center" mt={1} color="label">
                      Please stand by...
                    </Box>
                  </Stack.Item>
                )}

                {/* Generate Button */}
                {can_generate && !generation_in_progress && (
                  <Stack.Item>
                    <Button
                      icon="bolt"
                      fontSize="1.5rem"
                      height="4rem"
                      width="16rem"
                      color="good"
                      onClick={() => act('generate_new')}
                      tooltip="Generate a new Veilbreak dungeon portal"
                    >
                      <Stack align="center">
                        <Stack.Item>
                          <Icon name="portal" size={2} mr={1} />
                        </Stack.Item>
                        <Stack.Item>
                          <Box textAlign="center">
                            <Box bold>ACTIVATE PORTAL</Box>
                            <Box fontSize="0.8rem" opacity={0.8}>
                              Initialize New Dimension
                            </Box>
                          </Box>
                        </Stack.Item>
                      </Stack>
                    </Button>
                  </Stack.Item>
                )}

                {/* Active Portal Display */}
                {portal_active && !generation_in_progress && (
                  <Stack.Item>
                    <Box textAlign="center" mb={2}>
                      <Icon name="portal" size={3} color="good" mb={1} />
                      <Box bold fontSize="1.2rem" color="good">
                        PORTAL ACTIVE
                      </Box>
                      {portal_name && (
                        <Box color="violet" bold mt={1}>
                          Connected to: {portal_name}
                        </Box>
                      )}
                    </Box>
                  </Stack.Item>
                )}

                {/* No Portal Connected */}
                {!portal_present && (
                  <Stack.Item>
                    <Box textAlign="center" color="average">
                      <Icon name="exclamation-triangle" size={2} mb={1} />
                      <Box bold>No Portal Detected</Box>
                      <Box fontSize="0.9rem" mt={1}>
                        Use the Rescan button or ensure a portal is within range
                      </Box>
                    </Box>
                  </Stack.Item>
                )}

                {/* Portal Present but No Power */}
                {portal_present && !portal_status && (
                  <Stack.Item>
                    <Box textAlign="center" color="bad">
                      <Icon name="bolt" size={2} mb={1} />
                      <Box bold>Power Required</Box>
                      <Box fontSize="0.9rem" mt={1}>
                        Check portal power connections
                      </Box>
                    </Box>
                  </Stack.Item>
                )}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Information Panel */}
          <Stack.Item>
            <Section title="System Information">
              <LabeledList>
                <LabeledList.Item label="Portal Hardware">
                  <Box color={portal_present ? 'good' : 'bad'}>
                    {portal_present ? 'Detected' : 'Not Found'}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Power Grid">
                  <Box color={portal_status ? 'good' : 'bad'}>
                    {portal_status ? 'Stable' : 'Unstable'}
                  </Box>
                </LabeledList.Item>
                {current_target && (
                  <LabeledList.Item label="Active Connection">
                    <Box color="blue">{current_target.name}</Box>
                  </LabeledList.Item>
                )}
              </LabeledList>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
