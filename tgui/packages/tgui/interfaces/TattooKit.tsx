// modular_zzveilbreak/code/modules/tattoo/TattooKit.tsx
import { useState } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Icon,
  Input,
  LabeledList,
  NoticeBox,
  ProgressBar,
  Section,
  Stack,
  Table,
  Tooltip,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type BodyPart = {
  zone: string;
  name: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
};

type Tattoo = {
  artist: string;
  design: string;
  color: string;
  layer: number;
  is_signature: boolean;
  font: string;
  flair: string;
  date_applied: string;
};

type Data = {
  // Target info
  target_name: string;
  target_ref: string;

  // Kit status
  ink_uses: number;
  max_ink_uses: number;
  applying: boolean;

  // Current design
  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string;
  ink_color: string;
  design_mode: boolean;
  debug_mode: boolean;

  // Options
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
  layer_options: Record<string, string>;

  // Data
  body_parts: BodyPart[];
  existing_tattoos: Tattoo[];
};

const TattooPreview = (props: {
  design: string;
  color: string;
  flair: string;
}) => {
  const { design, color, flair } = props;

  if (!design) {
    return (
      <Box textAlign="center" color="label" py={3}>
        No design entered
      </Box>
    );
  }

  return (
    <Section title="Design Preview" textAlign="center">
      <Box
        style={{
          border: '2px solid #555',
          borderRadius: '4px',
          padding: '1rem',
          minHeight: '80px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          color: color,
          fontFamily: 'Arial, sans-serif',
          fontSize: '14px',
          backgroundColor: 'rgba(0,0,0,0.3)',
        }}
      >
        {design}
      </Box>
    </Section>
  );
};

const BodyPartSelector = (props) => {
  const { act, data } = useBackend<Data>();
  const { body_parts = [] } = data;

  const [searchQuery, setSearchQuery] = useState('');

  const filteredParts = Array.isArray(body_parts)
    ? body_parts.filter((part) =>
        part.name.toLowerCase().includes(searchQuery.toLowerCase()),
      )
    : [];

  return (
    <Section
      title="Select Body Part"
      buttons={
        <Input
          placeholder="Search body parts..."
          value={searchQuery}
          onChange={(_, value) => setSearchQuery(value)}
          width="200px"
        />
      }
    >
      <Table>
        <Table.Row header>
          <Table.Cell>Body Part</Table.Cell>
          <Table.Cell collapsing>Tattoos</Table.Cell>
          <Table.Cell collapsing>Status</Table.Cell>
          <Table.Cell collapsing>Action</Table.Cell>
        </Table.Row>
        {filteredParts.length > 0 ? (
          filteredParts.map((part) => (
            <Table.Row key={part.zone} className="candystripe">
              <Table.Cell bold>{part.name}</Table.Cell>
              <Table.Cell collapsing>
                {part.current_tattoos}/{part.max_tattoos}
              </Table.Cell>
              <Table.Cell collapsing>
                <Box color={part.covered ? 'average' : 'good'}>
                  <Icon name={part.covered ? 'eye-slash' : 'eye'} />
                  {part.covered ? 'Covered' : 'Visible'}
                </Box>
              </Table.Cell>
              <Table.Cell collapsing>
                <Button
                  icon="paint-brush"
                  disabled={
                    part.covered || part.current_tattoos >= part.max_tattoos
                  }
                  tooltip={
                    part.covered
                      ? 'Body part is covered by clothing'
                      : part.current_tattoos >= part.max_tattoos
                        ? 'Maximum tattoos reached for this part'
                        : 'Design tattoo for this body part'
                  }
                  onClick={() => act('select_zone', { zone: part.zone })}
                >
                  Design
                </Button>
              </Table.Cell>
            </Table.Row>
          ))
        ) : (
          <Table.Row>
            <Table.Cell colSpan={4} textAlign="center" color="label">
              No body parts available or data not loaded
            </Table.Cell>
          </Table.Row>
        )}
      </Table>
    </Section>
  );
};

const TattooDesigner = (props) => {
  const { act, data } = useBackend<Data>();
  const {
    artist_name = '',
    tattoo_design = '',
    selected_zone = '',
    selected_layer = 2,
    selected_font = 'PEN_FONT',
    selected_flair = 'null',
    ink_color = '#000000',
    ink_uses = 0,
    max_ink_uses = 30,
    applying = false,
    font_options = {},
    flair_options = {},
    layer_options = {},
    existing_tattoos = [],
    body_parts = [],
  } = data;

  // Safely find the current part
  const currentPart = Array.isArray(body_parts)
    ? body_parts.find((part) => part.zone === selected_zone)
    : null;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section
          title={`Designing for: ${currentPart?.name || 'Unknown'}`}
          buttons={
            <Button icon="arrow-left" onClick={() => act('back_to_parts')}>
              Back to Body Parts
            </Button>
          }
        >
          <Stack>
            <Stack.Item grow>
              <LabeledList>
                <LabeledList.Item label="Artist Name">
                  <Input
                    value={artist_name}
                    placeholder="Enter artist name..."
                    onChange={(_, value) =>
                      act('set_artist', { artist: value })
                    }
                    width="100%"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Tattoo Design">
                  <Input
                    value={tattoo_design}
                    placeholder="Enter tattoo design text..."
                    onChange={(_, value) =>
                      act('set_design', { design: value })
                    }
                    width="100%"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Ink Color">
                  <Stack>
                    <Stack.Item>
                      <ColorBox color={ink_color} />
                    </Stack.Item>
                    <Stack.Item grow>
                      <Input
                        value={ink_color}
                        onChange={(_, value) =>
                          act('set_color', { color: value })
                        }
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button icon="palette" onClick={() => act('pick_color')}>
                        Pick
                      </Button>
                    </Stack.Item>
                  </Stack>
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>
            <Stack.Item width="200px">
              <TattooPreview
                design={tattoo_design}
                color={ink_color}
                flair={selected_flair}
              />
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      <Stack.Item>
        <Section title="Design Options">
          <Stack>
            <Stack.Item>
              <LabeledList>
                <LabeledList.Item label="Font Style">
                  <Dropdown
                    selected={selected_font}
                    options={font_options}
                    onSelected={(value) => act('set_font', { font: value })}
                    width="150px"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Text Flair">
                  <Dropdown
                    selected={selected_flair}
                    options={flair_options}
                    onSelected={(value) => act('set_flair', { flair: value })}
                    width="150px"
                  />
                </LabeledList.Item>
                <LabeledList.Item label="Layer">
                  <Dropdown
                    selected={selected_layer.toString()}
                    options={layer_options}
                    onSelected={(value) => act('set_layer', { layer: value })}
                    width="150px"
                  />
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>
            <Stack.Item grow>
              <Section title="Ink Status" textAlign="center">
                <ProgressBar
                  value={ink_uses}
                  minValue={0}
                  maxValue={max_ink_uses}
                  color={ink_uses > 0 ? 'good' : 'bad'}
                >
                  {ink_uses}/{max_ink_uses} uses remaining
                </ProgressBar>
                <Button
                  icon="fill-drip"
                  disabled={applying || ink_uses >= max_ink_uses}
                  onClick={() => act('refill_ink')}
                  mt={1}
                >
                  Refill Ink
                </Button>
              </Section>
            </Stack.Item>
            <Stack.Item>
              <Section title="Application" textAlign="center">
                <Button
                  icon="check"
                  color="good"
                  disabled={
                    applying || !artist_name || !tattoo_design || ink_uses <= 0
                  }
                  onClick={() => act('apply_tattoo')}
                  tooltip={
                    !artist_name
                      ? 'Artist name required'
                      : !tattoo_design
                        ? 'Tattoo design required'
                        : ink_uses <= 0
                          ? 'No ink remaining'
                          : 'Apply tattoo to selected body part'
                  }
                  fontSize="16px"
                  height="40px"
                  width="120px"
                >
                  {applying ? 'Applying...' : 'Apply Tattoo'}
                </Button>
              </Section>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {Array.isArray(existing_tattoos) && existing_tattoos.length > 0 && (
        <Stack.Item>
          <Section title="Existing Tattoos on this Body Part">
            <Table>
              <Table.Row header>
                <Table.Cell>Design</Table.Cell>
                <Table.Cell>Artist</Table.Cell>
                <Table.Cell>Layer</Table.Cell>
                <Table.Cell>Date</Table.Cell>
                <Table.Cell collapsing>Actions</Table.Cell>
              </Table.Row>
              {existing_tattoos.map((tattoo, index) => (
                <Table.Row key={index} className="candystripe">
                  <Table.Cell>
                    <Box
                      style={{
                        color: tattoo.color || '#000000',
                        fontFamily: 'Arial, sans-serif',
                      }}
                    >
                      {tattoo.design || 'Unknown design'}
                    </Box>
                  </Table.Cell>
                  <Table.Cell>{tattoo.artist || 'Unknown artist'}</Table.Cell>
                  <Table.Cell>
                    {layer_options[tattoo.layer?.toString()] || 'Normal'}
                  </Table.Cell>
                  <Table.Cell>
                    {tattoo.date_applied || 'Unknown date'}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      icon="trash"
                      color="bad"
                      tooltip="Remove this tattoo"
                      onClick={() => act('remove_tattoo', { index: index + 1 })}
                    >
                      Remove
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        </Stack.Item>
      )}
    </Stack>
  );
};

export const TattooKit = (props) => {
  const { data } = useBackend<Data>();
  const {
    target_name = 'None',
    design_mode = false,
    debug_mode = false,
  } = data;

  return (
    <Window
      title="Professional Tattoo Kit"
      width={800}
      height={700}
      theme="abstract"
    >
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item grow>
                  <Box bold fontSize="16px">
                    Tattoo Kit - Target: {target_name}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  {debug_mode && <NoticeBox info>Debug Mode Active</NoticeBox>}
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            {design_mode ? <TattooDesigner /> : <BodyPartSelector />}
          </Stack.Item>

          <Stack.Item>
            <Section>
              <Box color="label" textAlign="center">
                <Icon name="info-circle" mr={1} />
                Tip: Use %s in artist name to automatically insert your name
                when applying
              </Box>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
