// tgui/packages/tgui/interfaces/PortalControl.tsx

import {
  Box,
  Button,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend, useLocalState } from '../backend';
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
  generation_status: string;
  generation_progress: number;
  generation_cooldown: number;
  generate_cooldown: number;
  can_generate: boolean;
  generation_in_progress: boolean;
  portal_name?: string;
}

export const PortalControl = (props, context) => {
  const { act, data } = useBackend<PortalControlData>(context);
  const [updateCount, setUpdateCount] = useLocalState(
    context,
    'updateCount',
    0,
  );

  const {
    portal_present,
    portal_status,
    portal_active,
    current_target,
    generation_status,
    generation_progress,
    generation_cooldown,
    generate_cooldown,
    can_generate,
    generation_in_progress,
    portal_name,
  } = data;

  // Force refresh more frequently during generation
  if (generation_in_progress || generation_status === 'generating') {
    setTimeout(() => {
      setUpdateCount(updateCount + 1);
    }, 500);
  }

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
    if (portal_active) {
      return 'Deactivate current portal before generating a new one';
    }
    if (generation_in_progress) {
      return 'Portal stabilization in progress...';
    }
    if (generation_status === 'ready') {
      return 'Portal already stabilized and ready';
    }
    if (!can_generate) {
      return 'Cannot generate at this time';
    }
    return 'Generate new portal destination';
  };

  const generateDisabled =
    portal_active ||
    generation_in_progress ||
    generation_status === 'ready' ||
    !can_generate;

  return (
    <Window width={500} height={400} theme="admin">
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
                disabled={generateDisabled}
                tooltip={getGenerateTooltip()}
                onClick={() => act('generate_new')}
              >
                {generation_status === 'ready'
                  ? 'Portal Ready'
                  : 'Generate New Portal'}
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

            {portal_name && (
              <Stack.Item>
                <Section title="Active Portal Destination">
                  <Box textAlign="center" bold fontSize={1.2}>
                    {portal_name}
                  </Box>
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
