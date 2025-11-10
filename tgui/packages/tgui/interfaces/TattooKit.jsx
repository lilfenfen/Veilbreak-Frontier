// tgui/packages/tgui/interfaces/TattooKit.jsx
import React from 'react';
import { useBackend } from '../backend';
import {
  Section,
  Tabs,
  Box,
  Button,
  Stack,
  ProgressBar,
  ColorBox,
  Input,
  TextArea,
  LabeledList,
  Table,
} from 'tgui-core/components';
import { Window } from '../layouts';

export const TattooKit = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    ink_color,
    selected_zone,
    body_parts,
    artist_name,
    tattoo_design,
    selected_layer,
    selected_font,
    preview_text,
  } = data;

  const inkFraction = max_ink_uses ? ink_uses / max_ink_uses : 0;
  const canApply = selected_zone && artist_name && tattoo_design && ink_uses > 0;

  const PreviewBox = ({ html }) => (
    <Box
      style={{
        background: '#0F1720',
        padding: '10px',
        borderRadius: '6px',
        minHeight: '160px',
        maxHeight: '260px',
        overflowY: 'auto',
        border: '1px solid rgba(255,255,255,0.04)',
      }}
    >
      <div dangerouslySetInnerHTML={{ __html: html || "<i>No preview available.</i>" }} />
    </Box>
  );

  const handleArtistChange = (value) => {
    act('set_artist', { value: value });
  };

  const handleDesignChange = (value) => {
    act('set_design', { value: value });
  };

  return (
    <Window width={760} height={620} theme="ntos">
      <Window.Content scrollable>
        <Section title={`Tattoo Kit — Target: ${target_name}`}>
          <Stack fill align="center">
            <Stack.Item grow>
              <ProgressBar value={inkFraction} />
              <Box mt={1}>Ink: {ink_uses}/{max_ink_uses}</Box>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item>
                  <Box>Ink Color</Box>
                </Stack.Item>
                <Stack.Item>
                  <ColorBox color={ink_color} />
                </Stack.Item>
                <Stack.Item>
                  <Button ml={1} onClick={() => act('change_color')}>
                    Choose
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button ml={1} onClick={() => act('refill_ink')}>
                    Refill
                  </Button>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>

        <Section fill fitted scrollable>
          <Tabs>
            <Tabs.Tab
              selected={!selected_zone}
              onClick={() => act('select_zone', { zone: null })}>
              Body Parts
            </Tabs.Tab>
            <Tabs.Tab
              selected={!!selected_zone}
              onClick={() => {}}>
              Design
            </Tabs.Tab>
          </Tabs>
        </Section>

        {!selected_zone && (
          <Section title="Select a Body Part">
            <Stack wrap>
              {body_parts.map((part) => (
                <Stack.Item key={part.zone}>
                  <Button
                    m={0.5}
                    selected={selected_zone === part.zone}
                    onClick={() => act('select_zone', { zone: part.zone })}
                  >
                    {part.name}
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          </Section>
        )}

        {selected_zone && (
          <Section title={`Design — ${selected_zone}`}>
            <LabeledList>
              <LabeledList.Item label="Artist">
                <Input
                  fluid
                  value={artist_name}
                  placeholder="Artist name"
                  onChange={(e, value) => handleArtistChange(value)}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Design (text)">
                <TextArea
                  fluid
                  rows={4}
                  value={tattoo_design}
                  placeholder="Describe the design"
                  onChange={(e, value) => handleDesignChange(value)}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Layer">
                <Stack>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 1}
                      onClick={() => act('set_layer', { layer: 1 })}
                      tooltip="Under layer - appears below clothing"
                    >
                      Under
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 2}
                      onClick={() => act('set_layer', { layer: 2 })}
                      tooltip="Normal layer - standard placement"
                    >
                      Normal
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 3}
                      onClick={() => act('set_layer', { layer: 3 })}
                      tooltip="Over layer - appears above clothing"
                    >
                      Over
                    </Button>
                  </Stack.Item>
                </Stack>
              </LabeledList.Item>

              <LabeledList.Item label="Font">
                <Stack>
                  <Stack.Item>
                    <Button
                      selected={selected_font === 'PEN_FONT'}
                      onClick={() => act('set_font', { font: 'PEN_FONT' })}
                    >
                      Pen
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_font === 'FOUNTAIN_PEN_FONT'}
                      onClick={() => act('set_font', { font: 'FOUNTAIN_PEN_FONT' })}
                    >
                      Fountain
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_font === 'PRINTER_FONT'}
                      onClick={() => act('set_font', { font: 'PRINTER_FONT' })}
                    >
                      Printer
                    </Button>
                  </Stack.Item>
                </Stack>
              </LabeledList.Item>
            </LabeledList>

            <Stack mt={1}>
              <Stack.Item>
                <Button
                  color="good"
                  onClick={() => act('apply_tattoo')}
                  disabled={!canApply}
                  tooltip={!canApply ? "Fill all required fields and ensure ink is available" : "Apply the tattoo"}
                >
                  Apply Tattoo
                </Button>
              </Stack.Item>
              <Stack.Item>
                <Button
                  ml={1}
                  onClick={() => act('select_zone', { zone: null })}
                >
                  Back
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        )}

        <Section title="Preview & Details" fill>
          <Stack fill>
            <Stack.Item grow>
              <PreviewBox html={preview_text} />
            </Stack.Item>
            <Stack.Item width="40%">
              <Stack fill vertical>
                <Stack.Item>
                  <Section title="Current Design">
                    <Table>
                      <Table.Row>
                        <Table.Cell>Artist</Table.Cell>
                        <Table.Cell>{artist_name || "—"}</Table.Cell>
                      </Table.Row>
                      <Table.Row>
                        <Table.Cell>Design</Table.Cell>
                        <Table.Cell>{tattoo_design || "—"}</Table.Cell>
                      </Table.Row>
                      <Table.Row>
                        <Table.Cell>Layer</Table.Cell>
                        <Table.Cell>{selected_layer}</Table.Cell>
                      </Table.Row>
                      <Table.Row>
                        <Table.Cell>Font</Table.Cell>
                        <Table.Cell>{selected_font}</Table.Cell>
                      </Table.Row>
                      <Table.Row>
                        <Table.Cell>Ink</Table.Cell>
                        <Table.Cell>{ink_uses}/{max_ink_uses}</Table.Cell>
                      </Table.Row>
                    </Table>
                  </Section>
                </Stack.Item>
                <Stack.Item>
                  <Section title="Quick Actions">
                    <Stack>
                      <Stack.Item>
                        <Button
                          color="good"
                          onClick={() => act('apply_tattoo')}
                          disabled={!canApply}
                          fluid
                        >
                          Apply
                        </Button>
                      </Stack.Item>
                      <Stack.Item>
                        <Button
                          ml={1}
                          onClick={() => act('refill_ink')}
                          fluid
                        >
                          Refill Ink
                        </Button>
                      </Stack.Item>
                    </Stack>
                  </Section>
                </Stack.Item>
              </Stack>
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};

export default TattooKit;
