// tgui/packages/tgui/interfaces/TattooKit.jsx
import React, { useState, useEffect, useRef } from 'react';
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
    target_name = "None",
    ink_uses = 0,
    max_ink_uses = 0,
    ink_color = "#000000",
    selected_zone,
    body_parts = [],
    artist_name = "",
    tattoo_design = "",
    selected_layer = 2,
    selected_font = "PEN_FONT",
    preview_text = "",
  } = data;

  // Enhanced local state with sync tracking
  const [localArtist, setLocalArtist] = useState(artist_name);
  const [localDesign, setLocalDesign] = useState(tattoo_design);
  const [lastBackendArtist, setLastBackendArtist] = useState(artist_name);
  const [lastBackendDesign, setLastBackendDesign] = useState(tattoo_design);
  const [syncStatus, setSyncStatus] = useState("synced");

  // Refs to track pending updates
  const pendingArtistUpdate = useRef(false);
  const pendingDesignUpdate = useRef(false);

  // Robust sync with backend - handles sanitization conflicts
  useEffect(() => {
    if (artist_name !== lastBackendArtist) {
      // If we have a pending update, check if backend accepted it or modified it
      if (pendingArtistUpdate.current) {
        if (artist_name === localArtist) {
          // Backend accepted our update exactly
          setSyncStatus("synced");
        } else {
          // Backend modified our input - sync local to backend
          setLocalArtist(artist_name);
          setSyncStatus("backend_modified");
        }
        pendingArtistUpdate.current = false;
      } else {
        // External change from backend, sync local
        setLocalArtist(artist_name);
      }
      setLastBackendArtist(artist_name);
    }
  }, [artist_name, lastBackendArtist, localArtist]);

  useEffect(() => {
    if (tattoo_design !== lastBackendDesign) {
      if (pendingDesignUpdate.current) {
        if (tattoo_design === localDesign) {
          setSyncStatus("synced");
        } else {
          setLocalDesign(tattoo_design);
          setSyncStatus("backend_modified");
        }
        pendingDesignUpdate.current = false;
      } else {
        setLocalDesign(tattoo_design);
      }
      setLastBackendDesign(tattoo_design);
    }
  }, [tattoo_design, lastBackendDesign, localDesign]);

  const inkFraction = max_ink_uses ? ink_uses / max_ink_uses : 0;

  // Use UNSANITIZED local state for validation to match what user sees
  const canApply = selected_zone &&
                  localArtist && localArtist.length > 0 &&
                  localDesign && localDesign.length > 0 &&
                  ink_uses > 0;

  const handleArtistChange = (value) => {
    setLocalArtist(value);
    setSyncStatus("pending");
    pendingArtistUpdate.current = true;
    // Send RAW data to backend - let backend decide about sanitization
    act('set_artist', { value: value });
  };

  const handleDesignChange = (value) => {
    setLocalDesign(value);
    setSyncStatus("pending");
    pendingDesignUpdate.current = true;
    // Send RAW data to backend
    act('set_design', { value: value });
  };

  const PreviewBox = ({ html }) => (
    <Box
      style={{
        background: '#0F1720',
        padding: '10px',
        borderRadius: '6px',
        minHeight: '120px',
        maxHeight: '180px',
        overflowY: 'auto',
        border: '1px solid rgba(255,255,255,0.04)',
      }}
    >
      <div dangerouslySetInnerHTML={{ __html: html }} />
    </Box>
  );

  return (
    <Window width={760} height={600} theme="ntos">
      <Window.Content scrollable>
        {/* Sync Status Indicator */}
        <Section title={`Tattoo Kit — Target: ${target_name}`}>
          <Stack fill align="center">
            <Stack.Item grow>
              <ProgressBar value={inkFraction} />
              <Box mt={1}>Ink: {ink_uses}/{max_ink_uses}</Box>
            </Stack.Item>
            <Stack.Item>
              <Box color={
                syncStatus === "synced" ? "good" :
                syncStatus === "pending" ? "average" :
                "bad"
              }>
                Sync: {syncStatus}
              </Box>
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
                  value={localArtist}
                  placeholder="Artist name"
                  onChange={(e, value) => handleArtistChange(value)}
                />
              </LabeledList.Item>

              <LabeledList.Item label="Design (text)">
                <TextArea
                  fluid
                  rows={3}
                  value={localDesign}
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
                    >
                      Under
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 2}
                      onClick={() => act('set_layer', { layer: 2 })}
                    >
                      Normal
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 3}
                      onClick={() => act('set_layer', { layer: 3 })}
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

        <Section title="Data Integrity Monitor">
          <Table>
            <Table.Row>
              <Table.Cell>Local Artist</Table.Cell>
              <Table.Cell>"{localArtist}" (length: {localArtist?.length || 0})</Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Backend Artist</Table.Cell>
              <Table.Cell>"{artist_name}" (length: {artist_name?.length || 0})</Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Local Design</Table.Cell>
              <Table.Cell>"{localDesign}" (length: {localDesign?.length || 0})</Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Backend Design</Table.Cell>
              <Table.Cell>"{tattoo_design}" (length: {tattoo_design?.length || 0})</Table.Cell>
            </Table.Row>
            <Table.Row>
              <Table.Cell>Data Match</Table.Cell>
              <Table.Cell>
                {localArtist === artist_name && localDesign === tattoo_design ?
                  "✅ PERFECT SYNC" : "❌ OUT OF SYNC"}
              </Table.Cell>
            </Table.Row>
          </Table>
        </Section>

        <Section title="Preview & Details">
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
                        <Table.Cell>{localArtist || "—"}</Table.Cell>
                      </Table.Row>
                      <Table.Row>
                        <Table.Cell>Design</Table.Cell>
                        <Table.Cell>{localDesign || "—"}</Table.Cell>
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
                        <Table.Cell>Can Apply</Table.Cell>
                        <Table.Cell>{canApply ? "YES" : "NO"}</Table.Cell>
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
