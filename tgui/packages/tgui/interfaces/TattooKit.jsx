// tgui/packages/tgui/interfaces/TattooKit.jsx
import React from 'react';
import { useBackend } from '../backend';
import {
  Section,
  Tabs,
  Box,
  Button,
  Flex,
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

  // FIXED: Proper event handlers for input changes
  const handleArtistChange = (e, value) => {
    console.log("Artist change:", value); // Browser console debug
    act('set_artist', { value: value });
  };

  const handleDesignChange = (e, value) => {
    console.log("Design change:", value); // Browser console debug
    act('set_design', { value: value });
  };

  return (
    <Window width={760} height={620} theme="ntos">
      <Window.Content scrollable>
        <Section title={`Tattoo Kit — Target: ${target_name}`}>
          <Flex justify="space-between" align="center" wrap>
            <Box width="55%">
              <ProgressBar value={inkFraction} />
              <Box mt={1}>Ink: {ink_uses}/{max_ink_uses}</Box>
            </Box>
            <Box width="40%" align="right">
              <Box>Ink Color</Box>
              <Flex align="center" justify="flex-end">
                <ColorBox color={ink_color} />
                <Button ml={1} onClick={() => act('change_color')}>Choose</Button>
                <Button ml={1} onClick={() => act('refill_ink')}>Refill</Button>
              </Flex>
            </Box>
          </Flex>
        </Section>

        <Tabs>
          <Tabs.Tab selected={!selected_zone}>Body Parts</Tabs.Tab>
          <Tabs.Tab selected={!!selected_zone}>Design</Tabs.Tab>
        </Tabs>

        {!selected_zone && (
          <Section title="Select a Body Part">
            <Flex wrap>
              {body_parts.map((part) => (
                <Button
                  key={part.zone}
                  m={0.5}
                  selected={selected_zone === part.zone}
                  onClick={() => act('select_zone', { zone: part.zone })}
                >
                  {part.name}
                </Button>
              ))}
            </Flex>
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
                  onChange={handleArtistChange}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Design (text)">
                <TextArea
                  fluid
                  rows={4}
                  value={tattoo_design}
                  placeholder="Describe the design"
                  onChange={handleDesignChange}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Layer">
                <Flex>
                  <Button selected={selected_layer === 1} onClick={() => act('set_layer', { layer: 1 })}>Under</Button>
                  <Button selected={selected_layer === 2} onClick={() => act('set_layer', { layer: 2 })}>Normal</Button>
                  <Button selected={selected_layer === 3} onClick={() => act('set_layer', { layer: 3 })}>Over</Button>
                </Flex>
              </LabeledList.Item>

              <LabeledList.Item label="Font">
                <Flex>
                  <Button selected={selected_font === 'PEN_FONT'} onClick={() => act('set_font', { font: 'PEN_FONT' })}>Pen</Button>
                  <Button selected={selected_font === 'FOUNTAIN_PEN_FONT'} onClick={() => act('set_font', { font: 'FOUNTAIN_PEN_FONT' })}>Fountain</Button>
                  <Button selected={selected_font === 'PRINTER_FONT'} onClick={() => act('set_font', { font: 'PRINTER_FONT' })}>Printer</Button>
                </Flex>
              </LabeledList.Item>
            </LabeledList>

            <Flex mt={1}>
              <Button
                color="good"
                onClick={() => act('apply_tattoo')}
                disabled={!canApply}
              >
                Apply Tattoo
              </Button>
              <Button ml={1} onClick={() => act('select_zone', { zone: null })}>Back</Button>
            </Flex>
          </Section>
        )}

        <Section title="Preview & Details">
          <Flex>
            <Box width="60%">
              <PreviewBox html={preview_text} />
            </Box>

            <Box width="40%" ml={1}>
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

              <Section title="Quick Actions" mt={1}>
                <Button
                  color="good"
                  onClick={() => act('apply_tattoo')}
                  disabled={!canApply}
                >
                  Apply
                </Button>
                <Button ml={1} onClick={() => act('refill_ink')}>Refill Ink</Button>
              </Section>
            </Box>
          </Flex>
        </Section>
      </Window.Content>
    </Window>
  );
};

export default TattooKit;
