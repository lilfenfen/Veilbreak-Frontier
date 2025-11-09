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
    <Window title="Body Art Kit" width={600} height={700}>
      <Window.Content>
        <TattooKitContent />
      </Window.Content>
    </Window>
  );
};

const TattooKitContent = (props) => {
  const { act, data } = useBackend<TattooKitData>();

  // Provide safe defaults for all data with proper null checks
  const safeData = data || {};
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
  } = safeData;

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

  // Layer options
  const layerOptions = [
    { value: 1, displayText: 'Under' },
    { value: 2, displayText: 'Normal' },
    { value: 3, displayText: 'Over' },
  ];

  // Font options
  const fontOptions = [
    { value: 'Pen', displayText: 'Pen' },
    { value: 'Fountain Pen', displayText: 'Fountain' },
    { value: 'Crayon', displayText: 'Crayon' },
    { value: 'Printer', displayText: 'Printer' },
    { value: 'Charcoal', displayText: 'Charcoal' },
  ];

  // Safe body part validation
  const safeBodyParts = (() => {
    if (!body_parts) return [];
    if (!Array.isArray(body_parts)) return [];

    return body_parts.filter(part => {
      if (!part || typeof part !== 'object') return false;
      if (!part.zone || typeof part.zone !== 'string' || part.zone.trim() === '') return false;
      if (!part.name || typeof part.name !== 'string') return false;
      return true;
    });
  })();

  // Toggle expansion for a body part
  const handleToggleExpand = (zone: string) => {
    act('toggle_expand', { zone: zone });
  };

  // Update artist name for a specific body part
  const handleArtistChange = (zone: string, value: string) => {
    setLocalArtists(prev => ({ ...prev, [zone]: value }));
    act('set_artist_name', { zone: zone, value: value });
  };

  // Update tattoo design for a specific body part
  const handleDesignChange = (zone: string, value: string) => {
    setLocalDesigns(prev => ({ ...prev, [zone]: value }));
    act('set_tattoo_design', { zone: zone, value: value });
  };

  // Update layer for a specific body part
  const handleLayerChange = (zone: string, value: number) => {
    act('set_layer', { zone: zone, layer: value });
  };

  // Update font for a specific body part
  const handleFontChange = (zone: string, value: string) => {
    act('set_font', { zone: zone, font: value });
  };

  // Apply tattoo to a specific body part
  const handleApplyTattoo = (zone: string) => {
    act('apply_tattoo', { zone: zone });
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
      <Stack.Item>
        <Section title="Target Information">
          <LabeledList>
            <LabeledList.Item label="Target">
              {target_name}
            </LabeledList.Item>
            <LabeledList.Item label="Ink Remaining">
              {ink_uses} / {max_uses}
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <ColorBox color={ink_color} />
              <Button
                ml={1}
                icon="palette"
                onClick={() => act('change_ink_color')}
              >
                Change
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        <Section
          title="Body Parts"
          fill
          scrollable
          buttons={
            <Button
              icon="info"
              tooltip="Click on a body part to expand it and design a tattoo. Each part can have up to 5 tattoos."
            >
              Help
            </Button>
          }
        >
          <Stack vertical>
            {safeBodyParts.length > 0 ? (
              safeBodyParts.map((part) => {
                const partZone = part.zone || "chest";
                const partName = part.name || "Unknown";
                const partCovered = !!part.covered;
                const partCurrentTattoos = Number(part.current_tattoos) || 0;
                const partMaxTattoos = Number(part.max_tattoos) || 5;
                const partExpanded = !!part.expanded;
                const partPreview = part.preview_text || '';

                const currentArtist = localArtists[partZone] || '';
                const currentDesign = localDesigns[partZone] || '';
                const currentLayer = selected_layers[partZone] || 2;
                const currentFont = selected_fonts[partZone] || 'Pen';

                const canApply = !partCovered &&
                  partCurrentTattoos < partMaxTattoos &&
                  currentArtist?.trim() &&
                  currentDesign?.trim() &&
                  ink_uses > 0;

                return (
                  <Stack.Item key={partZone}>
                    <Section>
                      <Button
                        fluid
                        icon={partExpanded ? 'chevron-down' : 'chevron-right'}
                        onClick={() => handleToggleExpand(partZone)}
                        disabled={partCovered || partCurrentTattoos >= partMaxTattoos}
                      >
                        <Stack align="center">
                          <Stack.Item grow>
                            <Box fontSize="1.2em">{partName}</Box>
                            <Box>
                              Tattoos: {partCurrentTattoos}/{partMaxTattoos}
                            </Box>
                          </Stack.Item>
                          <Stack.Item>
                            {partCovered && (
                              <Box color="bad" bold>
                                COVERED
                              </Box>
                            )}
                            {partCurrentTattoos >= partMaxTattoos && (
                              <Box color="bad" bold>
                                FULL
                              </Box>
                            )}
                            {!partCovered && partCurrentTattoos < partMaxTattoos && (
                              <Box color="good" bold>
                                AVAILABLE
                              </Box>
                            )}
                          </Stack.Item>
                        </Stack>
                      </Button>

                      <Collapsible open={partExpanded}>
                        <Box mt={1}>
                          <Stack vertical>
                            <Stack.Item>
                              <LabeledList>
                                <LabeledList.Item label="Artist Name">
                                  <Input
                                    fluid
                                    value={currentArtist}
                                    onChange={(e, value) => handleArtistChange(partZone, value)}
                                    placeholder="Enter artist name..."
                                  />
                                </LabeledList.Item>
                              </LabeledList>
                            </Stack.Item>

                            <Stack.Item>
                              <Box mb={1}>Tattoo Design:</Box>
                              <Input.TextArea
                                fluid
                                height="80px"
                                value={currentDesign}
                                onChange={(e, value) => handleDesignChange(partZone, value)}
                                placeholder="Describe the tattoo design..."
                              />
                            </Stack.Item>

                            <Stack.Item>
                              <Stack>
                                <Stack.Item grow>
                                  <LabeledList>
                                    <LabeledList.Item label="Layer">
                                      <Dropdown
                                        width="100px"
                                        selected={currentLayer}
                                        options={layerOptions}
                                        onSelected={(value) => handleLayerChange(partZone, value)}
                                      />
                                    </LabeledList.Item>
                                  </LabeledList>
                                </Stack.Item>
                                <Stack.Item grow>
                                  <LabeledList>
                                    <LabeledList.Item label="Font">
                                      <Dropdown
                                        width="120px"
                                        selected={currentFont}
                                        options={fontOptions}
                                        onSelected={(value) => handleFontChange(partZone, value)}
                                      />
                                    </LabeledList.Item>
                                  </LabeledList>
                                </Stack.Item>
                              </Stack>
                            </Stack.Item>

                            {partPreview && (
                              <Stack.Item>
                                <Section title="Preview">
                                  <Box
                                    dangerouslySetInnerHTML={{
                                      __html: partPreview,
                                    }}
                                  />
                                </Section>
                              </Stack.Item>
                            )}

                            <Stack.Item>
                              <Button
                                fluid
                                color="good"
                                icon="check"
                                disabled={!canApply}
                                onClick={() => handleApplyTattoo(partZone)}
                              >
                                Apply Tattoo to {partName} (Costs 1 Ink)
                              </Button>
                            </Stack.Item>
                          </Stack>
                        </Box>
                      </Collapsible>
                    </Section>
                  </Stack.Item>
                );
              })
            ) : (
              <Stack.Item>
                <Box textAlign="center" color="bad">
                  No available body parts found!
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Section>
      </Stack.Item>
    </Stack>
  );
};
