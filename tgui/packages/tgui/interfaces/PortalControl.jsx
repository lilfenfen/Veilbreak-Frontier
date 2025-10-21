// tgui/packages/tgui/interfaces/PortalControl.jsx

import {
  Box,
  Button,
  ByondUi,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

export const PortalControl = () => {
  return (
    <Window width={400} height={500}>
      <Window.Content scrollable>
        <PortalControlContent />
      </Window.Content>
    </Window>
  );
};

const PortalControlContent = (props) => {
  const { act, data } = useBackend();
  const {
    portal_present = false,
    portal_status = false,
    current_target = null,
    destinations = [],
    generation_status = 'idle',
    dungeon_data = null,
  } = data;

  if (!portal_present) {
    return (
      <Section>
        <NoticeBox>No linked portal</NoticeBox>
        <Button fluid onClick={() => act('linkup')}>
          Link to Portal
        </Button>
      </Section>
    );
  }

  if (current_target) {
    return (
      <Section title={current_target.name}>
        <Stack vertical>
          <Stack.Item>
            <Box bold>Portal Active</Box>
            <Box>Destination: {current_target.name}</Box>
            {dungeon_data && (
              <Box>
                Size: {dungeon_data.dimensions?.width}x
                {dungeon_data.dimensions?.height} | Rooms:{' '}
                {dungeon_data.statistics?.rooms} | Difficulty:{' '}
                {dungeon_data.statistics?.mobs} threats
              </Box>
            )}
          </Stack.Item>
          <Stack.Item>
            <Button
              mt="2px"
              textAlign="center"
              fluid
              onClick={() => act('deactivate')}
            >
              Deactivate Portal
            </Button>
          </Stack.Item>
        </Stack>
      </Section>
    );
  }

  return (
    <Stack vertical>
      <Stack.Item>
        <Section title="Portal Control">
          {!portal_status && <NoticeBox>Portal Unpowered</NoticeBox>}
          <Button
            fluid
            mb={1}
            onClick={() => act('generate_new')}
            disabled={generation_status === 'generating'}
          >
            {generation_status === 'generating'
              ? 'Generating...'
              : generation_status === 'ready'
                ? 'Regenerate Dungeon'
                : 'Generate New Dungeon'}
          </Button>
          {generation_status === 'generating' && (
            <ProgressBar value={Math.random() * 100}>
              Stabilizing Portal...
            </ProgressBar>
          )}
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Available Destinations">
          {destinations.length === 0 ? (
            <Box>No portal destinations available.</Box>
          ) : (
            destinations.map((dest) => (
              <Box key={dest.ref} mb={1}>
                <Box bold>{dest.name}</Box>
                {(dest.available && (
                  <Button
                    fluid
                    onClick={() =>
                      act('activate', {
                        destination: dest.ref,
                      })
                    }
                  >
                    Activate Portal
                  </Button>
                )) || (
                  <>
                    <Box m={1} textColor="bad">
                      {dest.reason}
                    </Box>
                    {!!dest.timeout && (
                      <ProgressBar value={dest.timeout}>
                        Calibrating...
                      </ProgressBar>
                    )}
                  </>
                )}
              </Box>
            ))
          )}
        </Section>
      </Stack.Item>

      {dungeon_data && generation_status === 'ready' && (
        <Stack.Item>
          <Section title="Last Generated Dungeon">
            <Box>
              <Box bold>{dungeon_data.map_name}</Box>
              <Box>
                Size: {dungeon_data.dimensions?.width}x
                {dungeon_data.dimensions?.height}
              </Box>
              <Box>Rooms: {dungeon_data.statistics?.rooms}</Box>
              <Box>Threats: {dungeon_data.statistics?.mobs}</Box>
              <Box>Loot: {dungeon_data.statistics?.containers} containers</Box>
              <Box>Coverage: {dungeon_data.statistics?.coverage_percent}%</Box>
            </Box>
          </Section>
        </Stack.Item>
      )}
    </Stack>
  );
};
