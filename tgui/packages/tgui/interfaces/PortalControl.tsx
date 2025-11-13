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
  cleanup_in_progress: boolean;
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
    cleanup_in_progress,
    portal_name,
  } = data;

  // Enhanced status indicators with void-space theme
  const getPortalStatus = () => {
    if (cleanup_in_progress) {
      return {
        color: 'yellow',
        icon: 'exclamation-triangle',
        text: 'CONDUIT COLLAPSING',
        description: 'Emergency dimensional collapse in progress',
      };
    }
    if (!portal_present) {
      return {
        color: 'violet',
        icon: 'unlink',
        text: 'VOID CONDUIT OFFLINE',
        description: 'No dimensional conduit detected',
      };
    }
    if (!portal_status) {
      return {
        color: 'yellow',
        icon: 'bolt',
        text: 'POWER FLUCTUATION',
        description: 'Insufficient energy signature',
      };
    }
    if (portal_active) {
      return {
        color: 'good',
        icon: 'portal',
        text: 'VOID SPACE ACTIVE',
        description: 'Dimensional bridge stabilized',
      };
    }
    if (generation_in_progress) {
      return {
        color: 'blue',
        icon: 'cog',
        text: 'REALITY STABILIZATION',
        description: 'Calibrating dimensional matrix',
      };
    }
    return {
      color: 'blue',
      icon: 'check',
      text: 'VOID CONDUIT READY',
      description: 'Awaiting dimensional breach',
    };
  };

  const status = getPortalStatus();

  // Determine which main content to show
  const getMainContent = () => {
    if (cleanup_in_progress) {
      return (
        <Box textAlign="center">
          <Icon name="exclamation-triangle" size={4} color="yellow" />
          <Box bold fontSize="1.4rem" color="yellow" mt={1}>
            CONDUIT COLLAPSE INITIATED
          </Box>
          <Box color="yellow" bold mt={1} fontSize="1.1rem">
            <Icon name="radiation" mr={1} />
            EMERGENCY DIMENSIONAL COLLAPSE IN PROGRESS
          </Box>
          <Box textAlign="center" color="label" fontSize="0.9rem" mt={2}>
            <Icon name="clock" mr={1} />
            Stabilizing space-time continuum...
          </Box>
        </Box>
      );
    }

    if (generation_in_progress) {
      const safeProgress = Math.max(1, generation_progress);
      return (
        <Box textAlign="center">
          <Box mb={2}>
            <Icon name="cog" spin mr={1} size={1.5} />
            <strong>STABILIZING VOID SPACE MATRIX</strong>
          </Box>
          <ProgressBar
            value={safeProgress / 100}
            color="blue"
            ranges={{
              good: [0.75, 1],
              average: [0.25, 0.75],
              bad: [0, 0.25],
            }}
          >
            Dimensional Coherence: {safeProgress}%
          </ProgressBar>
          <Box mt={1} color="label" fontSize="0.9rem">
            Reality recalibration in progress...
          </Box>
        </Box>
      );
    }

    if (can_generate) {
      return (
        <Box textAlign="center">
          <Button
            fontSize="1.4rem"
            lineHeight="1.2"
            height="4rem"
            width="18rem" // Increased from 16rem to 18rem for better text fit
            color="good"
            onClick={() => act('generate_new')}
            tooltip="Initiate dimensional breach protocol"
          >
            <Box textAlign="center">
              <Icon name="portal" mr={1} size={1.5} />
              BREACH VOID SPACE
              <Box fontSize="0.9rem" opacity={0.8} mt={0.5}>
                Initialize Dimensional Conduit
              </Box>
            </Box>
          </Button>
        </Box>
      );
    }

    if (portal_active) {
      return (
        <Box textAlign="center">
          <Icon name="portal" size={4} color="good" />
          <Box bold fontSize="1.4rem" color="good" mt={1}>
            VOID SPACE CONDUIT ACTIVE
          </Box>
          {portal_name && (
            <Box color="violet" bold mt={1} fontSize="1.1rem">
              <Icon name="link" mr={1} />
              Connected to: {portal_name}
            </Box>
          )}
        </Box>
      );
    }

    if (!portal_present) {
      return (
        <Box textAlign="center" color="average">
          <Icon name="exclamation-triangle" size={3} />
          <Box bold fontSize="1.2rem" mt={1}>
            VOID CONDUIT OFFLINE
          </Box>
          <Box fontSize="0.9rem" mt={1}>
            No dimensional conduit detected in local space-time
          </Box>
        </Box>
      );
    }

    if (!portal_status) {
      return (
        <Box textAlign="center" color="yellow">
          <Icon name="bolt" size={3} />
          <Box bold fontSize="1.2rem" mt={1}>
            ENERGY SIGNATURE UNSTABLE
          </Box>
          <Box fontSize="0.9rem" mt={1}>
            Conduit requires stable power source for operation
          </Box>
        </Box>
      );
    }

    // Ready state - portal present, powered, but not active
    return (
      <Box textAlign="center" color="blue">
        <Icon name="check-circle" size={3} />
        <Box bold fontSize="1.2rem" mt={1}>
          VOID CONDUIT READY
        </Box>
        <Box fontSize="0.9rem" mt={1}>
          Dimensional conduit prepared for breach sequence
        </Box>
      </Box>
    );
  };

  // Check if we should show the DIMENSIONAL ANCHOR line
  const showDimensionalAnchor =
    current_target?.name && current_target.name !== '0' && !cleanup_in_progress;

  return (
    <Window width={500} height={460} theme="void">
      <Window.Content>
        {/* COMPLETELY REMOVED Stack - using direct structure */}
        <Box height="100%" display="flex" flexDirection="column">
          {/* Header Status Panel */}
          <Box>
            <Section
              title="VOID SPACE CONDUIT CONTROL"
              buttons={
                <Button
                  icon="sync-alt"
                  color="transparent"
                  onClick={() => act('linkup')}
                >
                  Rescan Matrix
                </Button>
              }
            >
              <LabeledList>
                <LabeledList.Item label="DIMENSIONAL STATUS">
                  <Box color={status.color} bold>
                    <Icon
                      name={status.icon}
                      spin={generation_in_progress && !cleanup_in_progress}
                      mr={1}
                    />
                    {status.text}
                  </Box>
                  <Box color="label" fontSize="0.8rem" mt={0.5}>
                    {status.description}
                  </Box>
                </LabeledList.Item>
                {portal_name && portal_active && !cleanup_in_progress && (
                  <LabeledList.Item label="ACTIVE CONNECTION">
                    <Box color="violet" bold>
                      <Icon name="external-link-alt" mr={1} />
                      {portal_name}
                    </Box>
                  </LabeledList.Item>
                )}
              </LabeledList>
            </Section>
          </Box>

          {/* Main Operations Panel - Takes remaining space */}
          <Box flexGrow={1} mt={1}>
            <Section
              title="VOID SPACE OPERATIONS"
              fill
              buttons={
                portal_active && !cleanup_in_progress ? (
                  <Button
                    icon="power-off"
                    color="bad"
                    onClick={() => act('deactivate')}
                  >
                    COLLAPSE CONDUIT
                  </Button>
                ) : null
              }
            >
              {/* Direct centered content */}
              <Box
                height="100%"
                display="flex"
                alignItems="center"
                justifyContent="center"
              >
                {getMainContent()}
              </Box>
            </Section>
          </Box>

          {/* Diagnostics Panel */}
          <Box mt={1}>
            <Section title="CONDUIT DIAGNOSTICS">
              <LabeledList>
                <LabeledList.Item label="CONDUIT HARDWARE">
                  <Box color={portal_present ? 'good' : 'violet'}>
                    {portal_present
                      ? 'SPACE-TIME SIGNATURE DETECTED'
                      : 'NO CONDUIT DETECTED'}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="ENERGY MATRIX">
                  <Box color={portal_status ? 'good' : 'yellow'}>
                    {portal_status ? 'QUANTUM STABILIZED' : 'FLUCTUATING'}
                  </Box>
                </LabeledList.Item>
                {showDimensionalAnchor && (
                  <LabeledList.Item label="DIMENSIONAL ANCHOR">
                    <Box color="blue">{current_target.name}</Box>
                  </LabeledList.Item>
                )}
                {cleanup_in_progress && (
                  <LabeledList.Item label="EMERGENCY STATUS">
                    <Box color="yellow" bold>
                      <Icon name="exclamation-triangle" mr={1} />
                      SPACE-TIME COLLAPSE IN PROGRESS
                    </Box>
                  </LabeledList.Item>
                )}
              </LabeledList>
            </Section>
          </Box>
        </Box>
      </Window.Content>
    </Window>
  );
};
