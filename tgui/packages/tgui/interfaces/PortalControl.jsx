// tgui/packages/tgui/interfaces/PortalControl.jsx

import {
  Box,
  Button,
  NoticeBox,
  ProgressBar,
  Section,
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
    generation_progress = 0,
    dungeon_data = null,
  } = data;

  if (!portal_present) {
    return (
      <Section>
        <NoticeBox>No linked portal</NoticeBox>
        <Button fluid onClick={() => act('linkup')}>
          Linkup
        </Button>
      </Section>
    );
  }

  if (current_target) {
    return (
      <Section title={current_target.name}>
        <Box bold>Portal Status: Active</Box>
        {dungeon_data && (
          <Box mt={1}>
            <Box bold>Dungeon Information:</Box>
            <Box>Name: {dungeon_data.map_name}</Box>
            <Box>
              Size: {dungeon_data.dimensions?.width}x
              {dungeon_data.dimensions?.height}
            </Box>
            <Box>Rooms: {dungeon_data.statistics?.rooms}</Box>
            <Box>Threats: {dungeon_data.statistics?.mobs}</Box>
            <Box>Loot: {dungeon_data.statistics?.containers} containers</Box>
          </Box>
        )}
        <Button
          mt="2px"
          textAlign="center"
          fluid
          onClick={() => act('deactivate')}
        >
          Deactivate
        </Button>
      </Section>
    );
  }

  if (!destinations.length) {
    return (
      <Section>
        <NoticeBox>No portal destinations detected.</NoticeBox>
        <Button
          fluid
          onClick={() => act('generate_new')}
          disabled={generation_status === 'generating'}
        >
          {generation_status === 'generating'
            ? `Generating... ${generation_progress}%`
            : 'Generate New Dungeon'}
        </Button>
        {generation_status === 'generating' && (
          <ProgressBar value={generation_progress}>
            Generating... {generation_progress}%
          </ProgressBar>
        )}
      </Section>
    );
  }

  return (
    <>
      {!portal_status && <NoticeBox>Portal Unpowered</NoticeBox>}

      <Section>
        <Button
          fluid
          mb={1}
          onClick={() => act('generate_new')}
          disabled={generation_status === 'generating'}
        >
          {generation_status === 'generating'
            ? `Generating... ${generation_progress}%`
            : 'Generate New Dungeon'}
        </Button>
        {generation_status === 'generating' && (
          <ProgressBar value={generation_progress}>
            Generating... {generation_progress}%
          </ProgressBar>
        )}
      </Section>

      {destinations.map((dest) => (
        <Section key={dest.ref} title={dest.name}>
          {(dest.available && (
            <Button
              fluid
              onClick={() =>
                act('activate', {
                  destination: dest.ref,
                })
              }
            >
              Activate
            </Button>
          )) || (
            <>
              <Box m={1} textColor="bad">
                {dest.reason}
              </Box>
              {!!dest.timeout && (
                <ProgressBar value={dest.timeout}>Calibrating...</ProgressBar>
              )}
            </>
          )}
        </Section>
      ))}

      {dungeon_data && generation_status === 'ready' && (
        <Section title="Generated Dungeon Ready">
          <Box bold>{dungeon_data.map_name}</Box>
          <Box>
            Size: {dungeon_data.dimensions?.width}x
            {dungeon_data.dimensions?.height}
          </Box>
          <Box>Rooms: {dungeon_data.statistics?.rooms}</Box>
          <Box>Threats: {dungeon_data.statistics?.mobs}</Box>
          <Box>Loot: {dungeon_data.statistics?.containers} containers</Box>
          <Box>Coverage: {dungeon_data.statistics?.coverage_percent}%</Box>
        </Section>
      )}
    </>
  );
};
