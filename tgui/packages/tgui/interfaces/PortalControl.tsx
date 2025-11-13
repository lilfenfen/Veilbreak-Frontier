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

  // ZERO-PROOFING: Safe data transformation
  const safeGenerationProgress = generation_in_progress
    ? Math.max(1, Math.min(100, generation_progress || 1))
    : -1; // Use -1 to indicate no progress should show

  const safePortalName =
    portal_name && portal_name !== '0' && portal_name !== '0%'
      ? portal_name
      : null;

  const safeTargetName =
    current_target?.name && current_target.name !== '0'
      ? current_target.name
      : null;

  // Enhanced status indicators with void-space theme
  const getPortalStatus = () => {
    if (cleanup_in_progress) {
      return {
        color: 'yellow',
        icon: 'exclamation-triangle',
        text: 'CONDUIT COLLAPSING',
        description: 'Emergency dimensional collapse in progress',
        showProgress: false,
      };
    }
    if (!portal_present) {
      return {
        color: 'violet',
        icon: 'unlink',
        text: 'VOID CONDUIT OFFLINE',
        description: 'No dimensional conduit detected',
        showProgress: false,
      };
    }
    if (!portal_status) {
      return {
        color: 'yellow',
        icon: 'bolt',
        text: 'POWER FLUCTUATION',
        description: 'Insufficient energy signature',
        showProgress: false,
      };
    }
    if (portal_active) {
      return {
        color: 'good',
        icon: 'portal',
        text: 'VOID SPACE ACTIVE',
        description: 'Dimensional bridge stabilized',
        showProgress: false,
      };
    }
    if (generation_in_progress) {
      return {
        color: 'blue',
        icon: 'cog',
        text: 'REALITY STABILIZATION',
        description: 'Calibrating dimensional matrix',
        showProgress: true,
      };
    }
    return {
      color: 'blue',
      icon: 'check',
      text: 'VOID CONDUIT READY',
      description: 'Awaiting dimensional breach',
      showProgress: false,
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
                          spin={generation_in_progress && !cleanup_in_progress}
                          mr={1}
                          size={1.2}
                        />
                        {status.text}
                      </Box>
                      <Box color="label" fontSize="0.8rem" mt={0.5}>
                        {status.description}
                      </Box>
                    </LabeledList.Item>
                    {safePortalName && !cleanup_in_progress && (
                      <LabeledList.Item
                        label="ACTIVE CONNECTION"
                        className="ConnectionLabel"
                      >
                        <Box color="violet" bold className="PortalName">
                          <Icon name="external-link-alt" mr={1} />
                          {safePortalName}
                        </Box>
                      </LabeledList.Item>
                    )}
                  </LabeledList>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Main Control Panel - COMPLETELY ZERO-PROOFED */}
          <Stack.Item grow>
            <Section
              title="VOID SPACE OPERATIONS"
              fill
              className="VoidOperations"
              buttons={
                portal_active && !cleanup_in_progress ? (
                  <Button
                    icon="power-off"
                    color="bad"
                    fontSize="1.1rem"
                    onClick={() => act('deactivate')}
                    tooltip="Emergency dimensional collapse"
                  >
                    COLLAPSE CONDUIT
                  </Button>
                ) : (
                  <Box style={{ width: '1px', height: '1px', opacity: 0 }}>
                    &nbsp;
                  </Box>
                )
              }
            >
              <Stack
                vertical
                fill
                align="center"
                justify="center"
                style={{ minHeight: '200px' }}
              >
                {/* STATE 1: Collapse Warning - ABSOLUTE PRIORITY */}
                {cleanup_in_progress && (
                  <Stack.Item>
                    <Box textAlign="center">
                      <Icon
                        name="exclamation-triangle"
                        size={4}
                        color="yellow"
                        className="CollapseWarningIcon"
                      />
                      <Box bold fontSize="1.4rem" color="yellow" mt={1}>
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
                      <Box
                        textAlign="center"
                        color="label"
                        fontSize="0.9rem"
                        mt={2}
                      >
                        <Icon name="clock" mr={1} />
                        Stabilizing space-time continuum...
                      </Box>
                    </Box>
                  </Stack.Item>
                )}

                {/* STATE 2: Generation Progress - ONLY when progress > 0 */}
                {!cleanup_in_progress &&
                  generation_in_progress &&
                  safeGenerationProgress > 0 && (
                    <Stack.Item width="95%">
                      <Box textAlign="center" mb={2}>
                        <Icon name="cog" spin mr={1} size={1.5} />
                        <strong>STABILIZING VOID SPACE MATRIX</strong>
                      </Box>
                      <ProgressBar
                        value={safeGenerationProgress / 100}
                        color="blue"
                        ranges={{
                          good: [0.75, 1],
                          average: [0.25, 0.75],
                          bad: [0, 0.25],
                        }}
                        className="VoidProgress"
                      >
                        Dimensional Coherence: {safeGenerationProgress}%
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

                {/* STATE 3: Generate Button */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  can_generate && (
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

                {/* STATE 4: Active Portal */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  portal_active && (
                    <Stack.Item>
                      <Box textAlign="center">
                        <Icon
                          name="portal"
                          size={4}
                          color="good"
                          className="ActivePortalIcon"
                        />
                        <Box bold fontSize="1.4rem" color="good" mt={1}>
                          VOID SPACE CONDUIT ACTIVE
                        </Box>
                        {safePortalName && (
                          <Box
                            color="violet"
                            bold
                            mt={1}
                            fontSize="1.1rem"
                            className="ActiveConnection"
                          >
                            <Icon name="link" mr={1} />
                            Connected to: {safePortalName}
                          </Box>
                        )}
                      </Box>
                    </Stack.Item>
                  )}

                {/* STATE 5: No Portal */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  !portal_present && (
                    <Stack.Item>
                      <Box textAlign="center" color="average">
                        <Icon name="exclamation-triangle" size={3} />
                        <Box bold fontSize="1.2rem" mt={1}>
                          VOID CONDUIT OFFLINE
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          No dimensional conduit detected in local space-time
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}

                {/* STATE 6: No Power */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  portal_present &&
                  !portal_status && (
                    <Stack.Item>
                      <Box textAlign="center" color="yellow">
                        <Icon name="bolt" size={3} />
                        <Box bold fontSize="1.2rem" mt={1}>
                          ENERGY SIGNATURE UNSTABLE
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          Conduit requires stable power source for operation
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}

                {/* STATE 7: Ready State */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  portal_present &&
                  portal_status &&
                  !portal_active &&
                  !can_generate && (
                    <Stack.Item>
                      <Box textAlign="center" color="blue">
                        <Icon name="check-circle" size={3} />
                        <Box bold fontSize="1.2rem" mt={1}>
                          VOID CONDUIT READY
                        </Box>
                        <Box fontSize="0.9rem" mt={1}>
                          Dimensional conduit prepared for breach sequence
                        </Box>
                      </Box>
                    </Stack.Item>
                  )}

                {/* STATE 8: FALLBACK - COMPLETELY EMPTY but prevents zeros */}
                {!cleanup_in_progress &&
                  !generation_in_progress &&
                  !can_generate &&
                  !portal_active &&
                  (!portal_present || (portal_present && portal_status)) && (
                    <Stack.Item>
                      {/* ABSOLUTELY NOTHING - not even hidden content */}
                    </Stack.Item>
                  )}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Enhanced Information Panel - ZERO-PROOFED */}
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
                {safeTargetName && !cleanup_in_progress && (
                  <LabeledList.Item
                    label="DIMENSIONAL ANCHOR"
                    className="DiagnosticItem"
                  >
                    <Box color="blue">{safeTargetName}</Box>
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
