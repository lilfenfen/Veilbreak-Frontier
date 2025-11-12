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
                <Stack.Item>
                  <Button
                    icon="bolt"
                    fluid
                    disabled={!can_generate || generation_in_progress}
                    onClick={() => act('generate_new')}
                  >
                    {generation_in_progress
                      ? `Generating... ${generation_progress}%`
                      : 'Generate New Portal'}
                  </Button>
                </Stack.Item>

                {generation_in_progress && (
                  <Stack.Item>
                    <ProgressBar value={generation_progress / 100} color="good">
                      Stabilizing... {generation_progress}%
                    </ProgressBar>
                  </Stack.Item>
                )}

                {portal_active && (
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
              </>
            )}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
