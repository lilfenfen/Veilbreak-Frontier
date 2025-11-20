// modular_zzveilbreak/code/modules/tattoo/TattooKit.tsx
import { type CSSProperties, useState } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Dropdown,
  Icon,
  Input,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Table,
  Tabs,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type DropdownOption = {
  name: string;
  value: string;
};

type BodyPart = {
  zone: string;
  name: string;
  covered: number;
  current_tattoos: number;
  max_tattoos: number;
};

type Tattoo = {
  artist: string;
  design: string;
  color: string;
  layer: number;
  font: string;
  flair: string;
  date: string;
};

type Data = {
  target_name: string;
  ink_uses: number;
  max_ink_uses: number;
  applying: boolean;

  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string;
  ink_color: string;
  design_mode: boolean;
  debug_mode: boolean;

  font_options: DropdownOption[];
  flair_options: DropdownOption[];
  layer_options: DropdownOption[];

  body_parts: BodyPart[];
  existing_tattoos: Tattoo[];
};

// Helper to map font keys to CSS font-family values for the preview
const getFontFamily = (fontKey: string): string => {
  const fontMap: Record<string, string> = {
    PEN_FONT: "'Courier New', Courier, monospace",
    IMPRINT_FONT: "'Times New Roman', Times, serif",
    SYNDICATE_FONT: "'Arial Black', Gadget, sans-serif",
    BUBBLEGUM_FONT: "'Comic Sans MS', cursive, sans-serif",
  };
  return fontMap[fontKey] || 'Arial, sans-serif';
};

// Helper to map flair keys to CSS styles for the preview
const getFlairStyle = (flairKey: string): CSSProperties => {
  const flairMap: Record<string, CSSProperties> = {
    FLAIR_SHADOW: { textShadow: '2px 2px 2px #333' },
    FLAIR_GLOW: { textShadow: '0 0 5px #fff, 0 0 10px #fff, 0 0 15px #0073e6' },
    FLAIR_ITALIC: { fontStyle: 'italic' },
    FLAIR_BOLD: { fontWeight: 'bold' },
  };
  return flairMap[flairKey] || {};
};

// Helper to map layer keys to CSS z-index values for the preview
const getLayerStyle = (layerKey: number): CSSProperties => {
  const layerMap: Record<number, CSSProperties> = {
    1: { zIndex: 1, position: 'relative' }, // Under
    2: { zIndex: 2, position: 'relative' }, // Normal
    3: { zIndex: 3, position: 'relative' }, // Over
  };
  return layerMap[layerKey] || {};
};

const BodyPartView = (props) => {
  const { act, data } = useBackend<Data>();
  const { body_parts = [] } = data;

  return (
    <Section title="Select Body Part" fill scrollable>
      <Table>
        <Table.Row header>
          <Table.Cell width="40%">Body Part</Table.Cell>
          <Table.Cell width="15%" textAlign="center">
            Status
          </Table.Cell>
          <Table.Cell width="20%" textAlign="center">
            Tattoos
          </Table.Cell>
          <Table.Cell width="25%" textAlign="center">
            Action
          </Table.Cell>
        </Table.Row>
        {body_parts.map((part, index) => {
          const isDisabled =
            part.covered || part.current_tattoos >= part.max_tattoos;
          const statusColor = part.covered ? 'bad' : 'good';
          const statusText = part.covered ? 'Covered' : 'Accessible';
          const tattooText = `${part.current_tattoos}/${part.max_tattoos}`;

          return (
            <Table.Row key={index} className="candystripe">
              <Table.Cell bold>{part.name}</Table.Cell>
              <Table.Cell textAlign="center">
                <Box color={statusColor}>
                  <Icon name={part.covered ? 'eye-slash' : 'eye'} mr={1} />
                  {statusText}
                </Box>
              </Table.Cell>
              <Table.Cell textAlign="center">
                <Box
                  color={
                    part.current_tattoos >= part.max_tattoos
                      ? 'average'
                      : 'good'
                  }
                >
                  {tattooText}
                </Box>
              </Table.Cell>
              <Table.Cell textAlign="center">
                <Button
                  icon="paint-brush"
                  disabled={isDisabled}
                  tooltip={
                    isDisabled
                      ? part.covered
                        ? 'Body part is covered by clothing'
                        : 'Maximum tattoos reached for this part'
                      : `Design tattoo for ${part.name}`
                  }
                  onClick={() => act('select_zone', { zone: part.zone })}
                >
                  Design
                </Button>
              </Table.Cell>
            </Table.Row>
          );
        })}
      </Table>
    </Section>
  );
};

const DesignStudio = (props) => {
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
    font_options = [],
    flair_options = [],
    layer_options = [],
    existing_tattoos = [],
  } = data;

  const [activeTab, setActiveTab] = useState('design');

  const currentPart = data.body_parts?.find(
    (p) => p.zone === selected_zone,
  ) || { name: 'Unknown' };

  const canApply = !applying && !!artist_name && !!tattoo_design && ink_uses > 0;

  // Helper functions to get display names
  const getFontName = (value: string) =>
    font_options.find((opt) => opt.value === value)?.name || value;

  const getFlairName = (value: string) =>
    flair_options.find((opt) => opt.value === value)?.name || value;

  const getLayerName = (value: number) =>
    layer_options.find((opt) => opt.value === value.toString())?.name ||
    `Layer ${value}`;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Section
          title={`Designing: ${currentPart.name}`}
          buttons={
            <Button icon="arrow-left" onClick={() => act('back')}>
              Back to Body Parts
            </Button>
          }
        >
          <Tabs>
            <Tabs.Tab
              selected={activeTab === 'design'}
              onClick={() => setActiveTab('design')}
            >
              <Icon name="paint-brush" mr={1} />
              Design
            </Tabs.Tab>
            <Tabs.Tab
              selected={activeTab === 'tattoos'}
              onClick={() => setActiveTab('tattoos')}
            >
              <Icon name="history" mr={1} />
              Existing Tattoos ({existing_tattoos?.length || 0})
            </Tabs.Tab>
          </Tabs>
        </Section>
      </Stack.Item>

      <Stack.Item grow>
        {activeTab === 'design' ? (
          <Stack fill>
            <Stack.Item grow={1}>
              <Section title="Design Details" fill>
                <Stack vertical fill>
                  <Stack.Item>
                    <LabeledList>
                      <LabeledList.Item label="Artist Name">
                        <Input
                          value={artist_name}
                          placeholder="Enter artist name..."
                          fluid
                          onChange={(_, value) =>
                            act('set_artist', { value: value || '' })
                          }
                        />
                      </LabeledList.Item>
                      <LabeledList.Item label="Tattoo Design">
                        <Input
                          value={tattoo_design}
                          placeholder="Enter tattoo text..."
                          fluid
                          onChange={(_, value) =>
                            act('set_design', { value: value || '' })
                          }
                        />
                      </LabeledList.Item>
                    </LabeledList>
                  </Stack.Item>

                  <Stack.Item grow>
                    <Section title="Live Preview" fill textAlign="center">
                      <Box
                        style={{
                          border: '2px solid #666',
                          borderRadius: '4px',
                          padding: '1rem',
                          minHeight: '100px',
                          color: ink_color,
                          fontFamily: 'Arial, sans-serif',
                          fontSize: '14px',
                          backgroundColor: 'rgba(0,0,0,0.05)',
                          wordBreak: 'break-word',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'center',
                        }}
                      >
                        {tattoo_design || 'Design preview will appear here...'}
                      </Box>
                    </Section>
                  </Stack.Item>
                </Stack>
              </Section>
            </Stack.Item>

            <Stack.Item width="300px">
              <Stack vertical fill>
                <Stack.Item>
                  <Section title="Color Settings">
                    <LabeledList>
                      <LabeledList.Item label="Ink Color">
                        <Stack>
                          <Stack.Item>
                            <ColorBox color={ink_color} />
                          </Stack.Item>
                          <Stack.Item grow>
                            <Input
                              value={ink_color}
                              fluid
                              onChange={(_, value) =>
                                act('set_color', { value: value || '#000000' })
                              }
                            />
                          </Stack.Item>
                          <Stack.Item>
                            <Button
                              icon="palette"
                              onClick={() => act('pick_color')}
                            >
                              Pick
                            </Button>
                          </Stack.Item>
                        </Stack>
                      </LabeledList.Item>
                    </LabeledList>
                  </Section>
                </Stack.Item>

                <Stack.Item>
                  <Section title="Style Options">
                    <LabeledList>
                      <LabeledList.Item label="Font">
                        <Dropdown
                          width="100%"
                          selected={selected_font}
                          options={font_options}
                          displayText={getFontName(selected_font)}
                          onSelected={(value) => act('set_font', { value })}
                        />
                      </LabeledList.Item>
                      <LabeledList.Item label="Flair">
                        <Dropdown
                          width="100%"
                          selected={selected_flair}
                          options={flair_options}
                          displayText={getFlairName(selected_flair)}
                          onSelected={(value) => act('set_flair', { value })}
                        />
                      </LabeledList.Item>
                      <LabeledList.Item label="Layer">
                        <Dropdown
                          width="100%"
                          selected={selected_layer?.toString()}
                          options={layer_options}
                          displayText={getLayerName(selected_layer)}
                          onSelected={(value) => act('set_layer', { value })}
                        />
                      </LabeledList.Item>
                    </LabeledList>
                  </Section>
                </Stack.Item>

                <Stack.Item>
                  <Section title="Preview" textAlign="center">
                    <Box
                      style={{
                        ...getFlairStyle(selected_flair),
                        ...getLayerStyle(selected_layer),
                        border: '2px solid #555',
                        padding: '1rem',
                        minHeight: '60px',
                        color: ink_color,
                        fontFamily: getFontFamily(selected_font),
                        fontSize: '14px',
                        backgroundColor: 'rgba(0,0,0,0.2)',
                        wordBreak: 'break-word',
                      }}
                    >
                      {tattoo_design || 'Enter design text...'}
                    </Box>
                  </Section>
                </Stack.Item>

                <Stack.Item>
                  <Section title="Application">
                    <ProgressBar
                      value={ink_uses}
                      minValue={0}
                      maxValue={max_ink_uses}
                      color={ink_uses > 0 ? 'good' : 'bad'}
                    >
                      Ink: {ink_uses}/{max_ink_uses}
                    </ProgressBar>
                    <Button
                      fluid
                      mt={1}
                      icon="check"
                      color={canApply ? 'good' : 'bad'}
                      disabled={!canApply}
                      onClick={() => act('apply')}
                    >
                      {applying ? 'Applying...' : 'Apply Tattoo'}
                    </Button>
                    <Button
                      fluid
                      mt={1}
                      icon="fill-drip"
                      onClick={() => act('refill')}
                    >
                      Refill Ink
                    </Button>
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        ) : (
          <Section fill scrollable title="Existing Tattoos">
            {existing_tattoos?.length > 0 ? (
              <Table>
                <Table.Row header>
                  <Table.Cell width="35%">Design</Table.Cell>
                  <Table.Cell width="20%">Artist</Table.Cell>
                  <Table.Cell width="15%">Layer</Table.Cell>
                  <Table.Cell width="20%">Date</Table.Cell>
                  <Table.Cell width="10%" textAlign="center">
                    Action
                  </Table.Cell>
                </Table.Row>
                {existing_tattoos.map((tattoo, index) => (
                  <Table.Row key={index} className="candystripe">
                    <Table.Cell>
                      <Box style={{ color: tattoo.color, fontWeight: 'bold' }}>
                        {tattoo.design}
                      </Box>
                    </Table.Cell>
                    <Table.Cell>{tattoo.artist}</Table.Cell>
                    <Table.Cell>{getLayerName(tattoo.layer)}</Table.Cell>
                    <Table.Cell>{tattoo.date}</Table.Cell>
                    <Table.Cell textAlign="center">
                      <Button
                        icon="trash"
                        color="bad"
                        tooltip="Remove this tattoo"
                        onClick={() => act('remove', { index: index + 1 })}
                      />
                    </Table.Cell>
                  </Table.Row>
                ))}
              </Table>
            ) : (
              <Box textAlign="center" color="label" py={4}>
                <Icon name="info-circle" size={2} mb={2} />
                <br />
                No tattoos on this body part
              </Box>
            )}
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};

export const TattooKit = (props) => {
  const { data } = useBackend<Data>();
  const { target_name, design_mode, ink_uses, max_ink_uses } = data;

  return (
    <Window title="Tattoo Kit" width={850} height={650} theme="abstract">
      <Window.Content>
        <Stack fill vertical>
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item grow>
                  <Box bold fontSize="16px">
                    <Icon name="palette" mr={1} />
                    Tattoo Kit - Client: {target_name}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Box color={ink_uses > 0 ? 'good' : 'bad'}>
                    <Icon name="fill-drip" mr={1} />
                    Ink: {ink_uses}/{max_ink_uses}
                  </Box>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          <Stack.Item grow>
            {design_mode ? <DesignStudio /> : <BodyPartView />}
          </Stack.Item>

          <Stack.Item>
            <Section>
              <Box color="label" textAlign="center">
                <Icon name="lightbulb" mr={1} />
                Pro Tip: Use %s in artist name to automatically insert your name
                when applying
              </Box>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};
