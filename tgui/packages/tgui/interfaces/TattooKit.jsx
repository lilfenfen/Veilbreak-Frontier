import { useState, useEffect } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Collapsible,
  Dropdown,
  Input,
  LabeledList,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

type TattooKitData = {
  target_name: string;
  ink_uses: number;
  max_uses: number;
  ink_color: string;
  expanded_parts: string[];
  artist_names: Record<string, string>;
  tattoo_designs: Record<string, string>;
  selected_layers: Record<string, number>;
  selected_fonts: Record<string, string>;
  body_parts: BodyPart[];
};

type BodyPart = {
  zone: string;
  name: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
  preview_text: string;
  expanded: boolean;
};

export const TattooKit = (props) => {
  return (
    <Window
      title="Body Art Kit"
      width={600}
      height={700}
      theme="abstract"
    >
      <Window.Content>
        <TattooKitContent />
      </Window.Content>
    </Window>
  );
};

const TattooKitContent = (props) => {
  const { act, data } = useBackend<TattooKitData>();
  const {
    target_name = "No Target",
    ink_uses = 0,
    max_uses = 20,
    ink_color = "#000000",
    expanded_parts = [],
    artist_names = {},
    tattoo_designs = {},
    selected_layers = {},
    selected_fonts = {},
    body_parts = [],
  } = data;

  // Local state for real-time form updates
  const [localArtists, setLocalArtists] = useState<Record<string, string>>({});
  const [localDesigns, setLocalDesigns] = useState<Record<string, string>>({});

  // Sync local state with backend data
  useEffect(() => {
    setLocalArtists(artist_names);
  }, [artist_names]);

  useEffect(() => {
    setLocalDesigns(tattoo_designs);
  }, [tattoo_designs]);

  // Constants
  const LAYER_OPTIONS = [
    { value: 1, displayText: 'Under' },
    { value: 2, displayText: 'Normal' },
    { value: 3, displayText: 'Over' },
  ];

  const FONT_OPTIONS = [
    { value: 'Pen', displayText: 'Pen' },
    { value: 'Fountain Pen', displayText: 'Fountain' },
    { value: 'Crayon', displayText: 'Crayon' },
    { value: 'Printer', displayText: 'Printer' },
    { value: 'Charcoal', displayText: 'Charcoal' },
  ];

  // Safe body part validation
  const safeBodyParts = Array.isArray(body_parts)
    ? body_parts.filter(part =>
        part?.zone &&
        typeof part.zone === 'string' &&
        part.zone.trim() &&
        part.name &&
        typeof part.name === 'string'
      )
    : [];

  // Event handlers
  const handleToggleExpand = (zone: string) => {
    act('toggle_expand', { zone });
  };

  const handleArtistChange = (zone: string, value: string) => {
    setLocalArtists(prev => ({ ...prev, [zone]: value }));
    act('set_artist_name', { zone, value });
  };

  const handleDesignChange = (zone: string, value: string) => {
    setLocalDesigns(prev => ({ ...prev, [zone]: value }));
    act('set_tattoo_design', { zone, value });
  };

  const handleLayerChange = (zone: string, value: number) => {
    act('set_layer', { zone, layer: value });
  };

  const handleFontChange = (zone: string, value: string) => {
    act('set_font', { zone, font: value });
  };

  const handleApplyTattoo = (zone: string) => {
    act('apply_tattoo', { zone });
  };

  const handleChangeInkColor = () => {
    act('change_ink_color');
  };

  // No target selected
  if (!target_name || target_name === "No Target") {
    return (
      <Section fill>
        <Box textAlign="center" fontSize="1.5em" bold>
          No Target Selected
        </Box>
        <Box textAlign="center" mt={2}>
          Use the tattoo kit on someone to apply tattoos.
        </Box>
      </Section>
    );
  }

  return (
    <Stack fill vertical>
      {/* Header Section */}
      <Stack.Item>
        <Section title="Target Information">
          <LabeledList>
            <LabeledList.Item label="Target">
              {target_name}
            </LabeledList.Item>
            <LabeledList.Item label="Ink Remaining">
              <Box color={ink_uses > 0 ? "good" : "bad"}>
                {ink_uses} / {max_uses}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <ColorBox color={ink_color} />
              <Button
                ml={1}
                icon="palette"
                onClick={handleChangeInkColor}
                tooltip="Change ink color"
              >
                Change
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>

      {/* Body Parts Section */}
      <Stack.Item grow>
        <Section
          title="Available Body Parts"
          fill
          scrollable
          buttons={
            <Button
              icon="info"
              tooltip="Click on a body part to expand it and design a tattoo. Each part can have up to 5 tattoos."
              tooltipPosition="left"
            >
              Help
            </Button>
          }
        >
          {safeBodyParts.length > 0 ? (
            <Stack vertical>
              {safeBodyParts.map((part) => {
                const {
                  zone,
                  name,
                  covered,
                  current_tattoos,
                  max_tattoos,
                  preview_text,
                  expanded
                } = part;

                const currentArtist = localArtists[zone] || '';
                const currentDesign = localDesigns[zone] || '';
                const currentLayer = selected_layers[zone] || 2;
                const currentFont = selected_fonts[zone] || 'Pen';

                const canApply = !covered &&
                  current_tattoos < max_tattoos &&
                  currentArtist?.trim() &&
                  currentDesign?.trim() &&
                  ink_uses > 0;

                const statusColor = covered ? "bad" :
                  current_tattoos >= max_tattoos ? "average" : "good";

                const statusText = covered ? "COVERED" :
                  current_tattoos >= max_tattoos ? "FULL" : "AVAILABLE";

                return (
                  <Stack.Item key={zone} mb={1}>
                    <Section>
                      {/* Header Button */}
                      <Button
                        fluid
                        icon={expanded ? 'chevron-down' : 'chevron-right'}
                        onClick={() => handleToggleExpand(zone)}
                        disabled={covered || current_tattoos >= max_tattoos}
                      >
                        <Stack align="center">
                          <Stack.Item grow>
                            <Box fontSize="1.2em" bold>
                              {name}
                            </Box>
                            <Box>
                              Tattoos: {current_tattoos}/{max_tattoos}
                            </Box>
                          </Stack.Item>
                          <Stack.Item>
                            <Box color={statusColor} bold>
                              {statusText}
                            </Box>
                          </Stack.Item>
                        </Stack>
                      </Button>

                      {/* Expanded Content */}
                      <Collapsible open={expanded}>
                        <Box mt={1}>
                          <Stack vertical spacing={1}>
                            {/* Artist Name */}
                            <Stack.Item>
                              <LabeledList>
                                <LabeledList.Item label="Artist Name">
                                  <Input
                                    fluid
                                    value={currentArtist}
                                    onChange={(e, value) => handleArtistChange(zone, value)}
                                    placeholder="Enter artist name or signature..."
                                    maxLength={50}
                                  />
                                </LabeledList.Item>
                              </LabeledList>
                            </Stack.Item>

                            {/* Tattoo Design */}
                            <Stack.Item>
                              <Box bold mb={0.5}>Tattoo Design:</Box>
                              <Input.TextArea
                                fluid
                                height="80px"
                                value={currentDesign}
                                onChange={(e, value) => handleDesignChange(zone, value)}
                                placeholder="Describe the tattoo design... (Supports emojis and special characters)"
                                maxLength={500}
                              />
                            </Stack.Item>

                            {/* Layer and Font Selection */}
                            <Stack.Item>
                              <Stack>
                                <Stack.Item grow>
                                  <LabeledList>
                                    <LabeledList.Item label="Layer">
                                      <Dropdown
                                        width="100%"
                                        selected={currentLayer}
                                        options={LAYER_OPTIONS}
                                        onSelected={(value) => handleLayerChange(zone, value)}
                                        tooltip="Layer determines display order"
                                      />
                                    </LabeledList.Item>
                                  </LabeledList>
                                </Stack.Item>
                                <Stack.Item grow>
                                  <LabeledList>
                                    <LabeledList.Item label="Font">
                                      <Dropdown
                                        width="100%"
                                        selected={currentFont}
                                        options={FONT_OPTIONS}
                                        onSelected={(value) => handleFontChange(zone, value)}
                                        tooltip="Font style for text elements"
                                      />
                                    </LabeledList.Item>
                                  </LabeledList>
                                </Stack.Item>
                              </Stack>
                            </Stack.Item>

                            {/* Preview */}
                            {preview_text && (
                              <Stack.Item>
                                <Section
                                  title="Preview"
                                  buttons={
                                    <Button
                                      icon="sync"
                                      tooltip="Preview updates in real-time"
                                      tooltipPosition="left"
                                    >
                                      Live
                                    </Button>
                                  }
                                >
                                  <Box
                                    style={{
                                      "min-height": "60px",
                                      "max-height": "120px",
                                      "overflow-y": "auto",
                                    }}
                                    dangerouslySetInnerHTML={{
                                      __html: preview_text,
                                    }}
                                  />
                                </Section>
                              </Stack.Item>
                            )}

                            {/* Apply Button */}
                            <Stack.Item>
                              <Button
                                fluid
                                color="good"
                                icon="check"
                                disabled={!canApply}
                                onClick={() => handleApplyTattoo(zone)}
                                tooltip={
                                  !canApply
                                    ? covered ? "Body part is covered"
                                    : current_tattoos >= max_tattoos ? "Body part has maximum tattoos"
                                    : !currentArtist?.trim() ? "Enter artist name"
                                    : !currentDesign?.trim() ? "Enter tattoo design"
                                    : ink_uses <= 0 ? "Out of ink"
                                    : "Apply tattoo"
                                    : "Apply tattoo to this body part"
                                }
                              >
                                Apply to {name} (Costs 1 Ink)
                              </Button>
                            </Stack.Item>
                          </Stack>
                        </Box>
                      </Collapsible>
                    </Section>
                  </Stack.Item>
                );
              })}
            </Stack>
          ) : (
            <Box textAlign="center" color="average" fontSize="1.2em" bold>
              No available body parts found!
            </Box>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};
