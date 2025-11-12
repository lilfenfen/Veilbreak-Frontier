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

  // Determine which buttons to show based on state
  const showGenerateButton =
    portal_present && !portal_active && !generation_in_progress && can_generate;
  const showGeneratingProgress = portal_present && generation_in_progress;
  const showDeactivateButton = portal_present && portal_active;

  return (
    <Window width={500} height={400}>
      <Window.Content>
        <Section title="Portal Control System">
          <LabeledList>
            <LabeledList.Item label="Portal Status">
              <Box color={portal_present ? 'good' : 'bad'}>
                {portal_present ? 'Connected' : 'Not Found'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Power Status">
              <Box color={portal_status ? 'good' : 'bad'}>
                {portal_status ? 'Powered' : 'No Power'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Portal State">
              <Box
                color={
                  portal_active
                    ? 'good'
                    : generation_in_progress
                      ? 'average'
                      : 'grey'
                }
              >
                {portal_active
                  ? 'Active'
                  : generation_in_progress
                    ? 'Generating...'
                    : 'Ready'}
              </Box>
            </LabeledList.Item>
            {portal_name && (
              <LabeledList.Item label="Destination">
                <Box color="blue">{portal_name}</Box>
              </LabeledList.Item>
            )}
          </LabeledList>
        </Section>

        <Section title="Portal Control">
          <Stack vertical fill>
            {!portal_present && (
              <Stack.Item>
                <Button icon="link" fluid onClick={() => act('linkup')}>
                  Scan for Portal
                </Button>
              </Stack.Item>
            )}

            {portal_present && (
              <>
                {/* Generate Button - Only show when portal is not active and not generating */}
                {showGenerateButton && (
                  <Stack.Item>
                    <Button
                      icon="bolt"
                      fluid
                      color="good"
                      onClick={() => act('generate_new')}
                    >
                      Generate New Portal
                    </Button>
                  </Stack.Item>
                )}

                {/* Generating Progress - Show when generating */}
                {showGeneratingProgress && (
                  <Stack.Item>
                    <ProgressBar value={generation_progress / 100} color="good">
                      Stabilizing Portal... {generation_progress}%
                    </ProgressBar>
                  </Stack.Item>
                )}

                {/* Deactivate Button - Only show when portal is active */}
                {showDeactivateButton && (
                  <Stack.Item>
                    <Button
                      icon="power-off"
                      fluid
                      color="bad"
                      onClick={() => act('deactivate')}
                    >
                      Deactivate Portal
                    </Button>
                  </Stack.Item>
                )}

                {/* Linkup Button - Always available for re-scanning */}
                <Stack.Item>
                  <Button icon="sync" fluid onClick={() => act('linkup')}>
                    Re-scan for Portal
                  </Button>
                </Stack.Item>
              </>
            )}
          </Stack>
        </Section>

        {/* Additional information section */}
        {current_target && (
          <Section title="Active Connection">
            <Box>
              Currently connected to:{' '}
              <Box as="span" color="blue" bold>
                {current_target.name}
              </Box>
            </Box>
            {portal_name && (
              <Box>
                Dungeon:{' '}
                <Box as="span" color="green" bold>
                  {portal_name}
                </Box>
              </Box>
            )}
          </Section>
        )}

        {/* Status messages */}
        {!portal_status && portal_present && (
          <Section title="Warning">
            <Box color="bad">
              Portal is not receiving power. Check power connections.
            </Box>
          </Section>
        )}
      </Window.Content>
    </Window>
  );
};
