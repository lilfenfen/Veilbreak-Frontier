// tgui/packages/tgui/interfaces/TattooKit.jsx
// Modernized TGUI for the Tattoo Kit. Uses available tgui-core components only.
// No Markdown dependency. Preview HTML is inserted into a safe preview box.

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
  Divider,
} from 'tgui-core/components';
import { Window } from '../layouts';

/**
 * TattooKit TGUI
 * Actions (act): select_zone, set_artist, set_design, set_layer, set_font, change_color, apply_tattoo, refill_ink
 */

export const TattooKit = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    target_name = "No Target",
    ink_uses = 0,
    max_ink_uses = 1,
    ink_color = "#000000",
    selected_zone = null,
    body_parts = [],
    artist_name = "",
    tattoo_design = "",
    selected_layer = 2,
    selected_font = "PEN_FONT",
    preview_text = "",
  } = data;

  const inkFraction = max_ink_uses ? ink_uses / max_ink_uses : 0;

  // Render preview HTML into a box via dangerouslySetInnerHTML (server provides sanitized HTML)
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
                <ColorBox color={ink_color || "#000000"} />
                <Button ml={1} onClick={() => act('change_color')}>Choose</Button>
                <Button ml={1} onClick={() => act('refill_ink')}>Refill</Button>
              </Flex>
            </Box>
          </Flex>
        </Section>

        <Tabs>
          <Tabs.Tab selected={!selected_zone}>Body Parts</Tabs.Tab>
          <Tabs.Tab selected={!!selected_zone}>Design</Tabs.Tab>
          <Tabs.Tab>Preview</Tabs.Tab>
        </Tabs>

        {/* Body Parts grid */}
        {!selected_zone && (
          <Section title="Select a Body Part">
            <Flex wrap>
              {body_parts.map((part) => (
                <Button
                  key={part.zone}
                  m={0.5}
                  selected={selected_zone === part.zone}
                  disabled={part.covered}
                  tooltip={part.covered ? 'Covered — remove clothing first' : `${part.current_tattoos}/${part.max_tattoos} tattoos`}
                  onClick={() => act('select_zone', { zone: part.zone })}
                >
                  {part.name}
                </Button>
              ))}
            </Flex>
            <Divider />
            <Box mt={1}><i>Select a body part to open the design editor. The preview pane will show applied tattoos and your design.</i></Box>
          </Section>
        )}

        {/* Design panel */}
        {selected_zone && (
          <Section title={`Design — ${selected_zone}`}>
            <LabeledList>
              <LabeledList.Item label="Artist">
                <Input
                  fluid
                  value={artist_name}
                  placeholder="Artist name"
                  onChange={(e, value) => act('set_artist', { value })}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Design (text)">
                <TextArea
                  fluid
                  rows={4}
                  value={tattoo_design}
                  placeholder="Describe the design (supports simple emoji codes)"
                  onChange={(e, value) => act('set_design', { value })}
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
              <Button color="good" onClick={() => act('apply_tattoo')}>Apply Tattoo</Button>
              <Button ml={1} onClick={() => act('select_zone', { zone: null })}>Back</Button>
            </Flex>
          </Section>
        )}

        {/* Preview Section */}
        <Section title="Preview">
          <Flex>
            <Box width="60%">
              {/* Server provides HTML snippet for preview; we render it safely here */}
              <PreviewBox html={preview_text} />
            </Box>

            <Box width="40%" ml={1}>
              <Section title="Details">
                <Table>
                  <Table.Row>
                    <Table.Cell>Artist</Table.Cell>
                    <Table.Cell>{artist_name || "—"}</Table.Cell>
                  </Table.Row>
                  <Table.Row>
                    <Table.Cell>Design</Table.Cell>
                    <Table.Cell>{tattoo_design ? tattoo_design.substring(0, 120) : "—"}</Table.Cell>
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
                  <Table.Row>
                    <Table.Cell>Color</Table.Cell>
                    <Table.Cell><ColorBox color={ink_color || "#000"} /></Table.Cell>
                  </Table.Row>
                </Table>
              </Section>

              <Section title="Quick Actions" mt={1}>
                <Button color="good" onClick={() => act('apply_tattoo')}>Apply</Button>
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
