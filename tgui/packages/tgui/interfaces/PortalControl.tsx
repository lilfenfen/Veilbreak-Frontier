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

  return (
    <Window width={500} height={460} theme="void">
      <Window.Content className="VoidSpace">
        <Stack vertical fill>
          {/* Enhanced Header Status Panel */}
          <Stack.Item>
            <Section
              title="VOID SPACE CONDUIT CONTROL"
              className="VoidHeader"
              buttons={
                <Button
                  icon="sync-alt"
                  color="transparent"
                  tooltip="Rescan for dimensional conduits"
                  onClick={() => act('linkup')}
                >
                  Rescan Matrix
                </Button>
              }
            >
              <Stack align="center">
                <Stack.Item grow>
                  <LabeledList>
                    <LabeledList.Item
                      label="DIMENSIONAL STATUS"
                      className="StatusLabel"
                    >
                      <Box color={status.color} bold className="StatusDisplay">
                        <Icon
                          name={status.icon}
                          spin={generation_in_progress}
                          mr={1}
                          size={1.2}
                        />
                        {status.text}
                      </Box>
                      <Box color="label" fontSize="0.8rem" mt={0.5}>
                        {status.description}
                      </Box>
                    </LabeledList.Item>
                    {portal_name && !cleanup_in_progress && (
                      <LabeledList.Item
                        label="ACTIVE CONNECTION"
                        className="ConnectionLabel"
                      >
                        <Box color="violet" bold className="PortalName">
                          <Icon name="external-link-alt" mr={1} />
                          {portal_name}
                        </Box>
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Main Control Panel - Enhanced */}
          <Stack.Item grow>
            <Section
              title="VOID SPACE OPERATIONS"
              fill
              className="VoidOperations"
              buttons={
                portal_active &&
                !cleanup_in_progress && (
                  <Button
                    icon="power-off"
                    color="bad"
                    fontSize="1.1rem"
                    onClick={() => act('deactivate')}
                    tooltip="Emergency dimensional collapse"
                  >
                    COLLAPSE CONDUIT
                  </Button>
                )
              }
            >
              <Stack vertical fill align="center" justify="center">
                {/* Collapse Warning - When conduit is collapsing */}
                {cleanup_in_progress && (
                  <Stack.Item width="100%">
                    <Box textAlign="center" mb={2}>
                      <Icon
                        name="exclamation-triangle"
                        size={4}
                        color="yellow"
                        mb={1}
                        className="CollapseWarningIcon"
                      />
                      <Box bold fontSize="1.4rem" color="yellow">
                        CONDUIT COLLAPSE INITIATED
                      </Box>
                      <Box
                        color="yellow"
                        bold
                        mt={1}
                        fontSize="1.1rem"
                        className="CollapseWarning"
                      >
                        <Icon name="radiation" mr={1} />
                        EMERGENCY DIMENSIONAL COLLAPSE IN PROGRESS
                      </Box>
                    </Box>
                    <Box
                      textAlign="center"
                      color="label"
                      fontSize="0.9rem"
                      mt={2}
                    >
                      <Icon name="clock" mr={1} />
                      Stabilizing space-time continuum...
                    </Box>
                  </Stack.Item>
                )}

                {/* Generation Progress - Only during stabilization */}
                {generation_in_progress && !cleanup_in_progress && (
                  <Stack.Item width="100%">
                    <Box textAlign="center" mb={2}>
                      <Icon name="cog" spin mr={1} size={1.5} />
                      <strong>STABILIZING VOID SPACE MATRIX</strong>
                    </Box>
                    <ProgressBar
                      value={generation_progress / 100}
                      color="blue"
                      ranges={{
                        good: [0.75, 1],
                        average: [0.25, 0.75],
                        bad: [0, 0.25],
                      }}
                      className="VoidProgress"
                    >
                      Dimensional Coherence: {generation_progress}%
                    </ProgressBar>
                    <Box
                      textAlign="center"
                      mt={1}
                      color="label"
                      fontSize="0.9rem"
                    >
                      Reality recalibration in progress...
                    </Box>
                  </Stack.Item>
                )}

                {/* Generate Button - Only when ready */}
                {can_generate &&
                  !generation_in_progress &&
                  !cleanup_in_progress && (
                    <Stack.Item>
                      <Button
                        fontSize="1.4rem"
                        lineHeight="1.2"
                        height="4rem"
                        width="16rem"
                        color="good"
                        className="GenerateButton"
                        onClick={() => act('generate_new')}
                        tooltip="Initiate dimensional breach protocol"
                      >
                        <Stack vertical align="center">
                          <Stack.Item>
                            <Icon name="portal" mr={1} size={1.5} />
                            BREACH VOID SPACE
                          </Stack.Item>
                          <Stack.Item fontSize="0.9rem" opacity={0.8}>
                            Initialize Dimensional Conduit
                          </Stack.Item>
                        </Stack>
                      </Button>
                    </Stack.Item>
                  )}

                {/* Active Portal Display - Only when active */}
                {portal_active &&
                  !generation_in_progress &&
                  !cleanup_in_progress && (
                    <Stack.Item>
                      <Box textAlign="center" mb={2}>
                        <Icon
                          name="portal"
                          size={4}
                          color="good"
                          mb={1}
                          className="ActivePortalIcon"
                        />
                        <Box bold fontSize="1.4rem" color="good">
                          VOID SPACE CONDUIT ACTIVE
                        </Box>
                        {portal_name && (
                          <Box
                            color="violet"
                            bold
                            mt={1}
                            fontSize="1.1rem"
                            className="ActiveConnection"
                          >
                            <Icon name="link" mr={1} />
                            Connected to: {portal_name}
                          </Box>
                        )}
                      </Box>
                    </Stack.Item>
                  )}

                {/* No Portal Connected - Only when missing */}
                {!portal_present &&
                  !generation_in_progress &&
                  !cleanup_in_progress && (
                    <Stack.Item>
                      <Box textAlign="center" color="average">
                        <Icon name="exclamation-triangle" size={3} mb={1} />
                        <Box bold fontSize="1.2rem">
                          VOID CONDUIT OFFLINE
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          No dimensional conduit detected in local space-time
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}

                {/* Portal Present but No Power - Only when relevant */}
                {portal_present &&
                  !portal_status &&
                  !generation_in_progress &&
                  !cleanup_in_progress && (
                    <Stack.Item>
                      <Box textAlign="center" color="yellow">
                        <Icon name="bolt" size={3} mb={1} />
                        <Box bold fontSize="1.2rem">
                          ENERGY SIGNATURE UNSTABLE
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          Conduit requires stable power source for operation
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}

                {/* Ready State - Only when portal is ready but not active */}
                {portal_present &&
                  portal_status &&
                  !portal_active &&
                  !can_generate &&
                  !generation_in_progress &&
                  !cleanup_in_progress && (
                    <Stack.Item>
                      <Box textAlign="center" color="blue">
                        <Icon name="check-circle" size={3} mb={1} />
                        <Box bold fontSize="1.2rem">
                          VOID CONDUIT READY
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          Dimensional conduit prepared for breach sequence
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Enhanced Information Panel */}
          <Stack.Item>
            <Section title="CONDUIT DIAGNOSTICS" className="VoidDiagnostics">
              <LabeledList>
                <LabeledList.Item
                  label="CONDUIT HARDWARE"
                  className="DiagnosticItem"
                >
                  <Box color={portal_present ? 'good' : 'violet'}>
                    {portal_present
                      ? 'SPACE-TIME SIGNATURE DETECTED'
                      : 'NO CONDUIT DETECTED'}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item
                  label="ENERGY MATRIX"
                  className="DiagnosticItem"
                >
                  <Box color={portal_status ? 'good' : 'yellow'}>
                    {portal_status ? 'QUANTUM STABILIZED' : 'FLUCTUATING'}
                  </Box>
                </LabeledList.Item>
                {current_target && !cleanup_in_progress && (
                  <LabeledList.Item
                    label="DIMENSIONAL ANCHOR"
                    className="DiagnosticItem"
                  >
                    <Box color="blue">{current_target.name}</Box>
                  </LabeledList.Item>
                )}
                {cleanup_in_progress && (
                  <LabeledList.Item
                    label="EMERGENCY STATUS"
                    className="DiagnosticItem"
                  >
                    <Box color="yellow" bold>
                      <Icon name="exclamation-triangle" mr={1} />
                      SPACE-TIME COLLAPSE IN PROGRESS
                    </Box>
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
