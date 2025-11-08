import { useState, useEffect } from 'react';
import {
  Box,
  Button,
  ColorBox,
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
  selected_zone: string;
  selected_zone_name: string;
  current_step: string;
  selected_layer: number;
  selected_font: string;
  artist_name: string;
  tattoo_design: string;
  body_parts: BodyPart[];
  preview_text: string;
};

type BodyPart = {
  zone: string;
  name: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
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

  // LINE 45: Provide safe defaults for all data
  const safeData = data || {};
  const {
    target_name = "No Target",
    ink_uses = 0,
    max_uses = 20,
    ink_color = "#000000",
    selected_zone = "chest",
    selected_zone_name = "chest",
    current_step = "select_part",
    selected_layer = 2,
    selected_font = "Pen",
    artist_name = "",
    tattoo_design = "",
    body_parts = [],
    preview_text = "",
  } = safeData;

  const [localArtist, setLocalArtist] = useState(artist_name || "");
  const [localDesign, setLocalDesign] = useState(tattoo_design || "");

  // Sync local state with backend data
  useEffect(() => {
    setLocalArtist(artist_name || "");
  }, [artist_name]);

  useEffect(() => {
    setLocalDesign(tattoo_design || "");
  }, [tattoo_design]);

  // Safe layer options
  const layerOptions = [
    { value: '1', displayText: 'Under' },
    { value: '2', displayText: 'Normal' },
    { value: '3', displayText: 'Over' },
  ];

  // Safe font options
  const fontOptions = [
    { value: 'Pen', displayText: 'Pen' },
    { value: 'Fountain Pen', displayText: 'Fountain' },
    { value: 'Crayon', displayText: 'Crayon' },
    { value: 'Printer', displayText: 'Printer' },
    { value: 'Charcoal', displayText: 'Charcoal' },
  ];

  // LINE 85: CRITICAL FIX - Only include body parts with valid zones
  const safeBodyParts = (() => {
    if (!body_parts) return [];
    if (!Array.isArray(body_parts)) return [];
    return body_parts.filter(part =>
      part &&
      typeof part === 'object' &&
      part.zone &&
      typeof part.zone === 'string' &&
      part.zone.trim() !== ''
    );
  })();

  // LINE 97: CRITICAL FIX - Safe body part selection handler
  const handleSelectBodypart = (zone: string) => {
    if (!zone || typeof zone !== 'string' || zone.trim() === '') {
      return;
    }
    act('select_bodypart', { zone: zone });
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

  if (current_step === 'select_part') {
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
            title="Select Body Part"
            fill
            scrollable
            buttons={
              <Button
                icon="info"
                tooltip="Select a body part to apply a tattoo to. The part must be exposed and have less than 5 tattoos."
              >
                Help
              </Button>
            }
          >
            <Stack vertical>
              {safeBodyParts.length > 0 ? (
                safeBodyParts.map((part) => {
                  // LINE 160: CRITICAL FIX - Use actual zone from data, no fallbacks
                  const partZone = part.zone;
                  const partName = part.name || "Unknown";
                  const partCovered = !!part.covered;
                  const partCurrentTattoos = Number(part.current_tattoos) || 0;
                  const partMaxTattoos = Number(part.max_tattoos) || 5;

                  return (
                    <Stack.Item key={partZone}>
                      <Button
                        fluid
                        disabled={partCovered || partCurrentTattoos >= partMaxTattoos}
                        onClick={() => handleSelectBodypart(partZone)}
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
                            {!partCovered &&
                              partCurrentTattoos < partMaxTattoos && (
                              <Box color="good" bold>
                                AVAILABLE
                              </Box>
                            )}
                          </Stack.Item>
                        </Stack>
                      </Button>
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
  }

  if (current_step === 'design_tattoo') {
    return (
      <Stack fill vertical>
        <Stack.Item>
          <Section title="Tattoo Design">
            <LabeledList>
              <LabeledList.Item label="Target">
                {target_name}
              </LabeledList.Item>
              <LabeledList.Item label="Body Part">
                {selected_zone_name}
                <Button
                  ml={1}
                  icon="arrow-left"
                  onClick={() => act('back_to_selection')}
                >
                  Change
                </Button>
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
              <LabeledList.Item label="Layer">
                <Dropdown
                  width="120px"
                  selected={String(selected_layer || 2)}
                  options={layerOptions}
                  onSelected={(value) => {
                    const layerNum = parseInt(value, 10);
                    if (!isNaN(layerNum)) {
                      act('set_layer', { layer: layerNum });
                    }
                  }}
                />
              </LabeledList.Item>
              <LabeledList.Item label="Font">
                <Dropdown
                  width="120px"
                  selected={selected_font || 'Pen'}
                  options={fontOptions}
                  onSelected={(value) => act('set_font', { font: value })}
                />
              </LabeledList.Item>
            </LabeledList>
          </Section>
        </Stack.Item>
        <Stack.Item grow>
          <Section title="Tattoo Details" fill>
            <Stack fill vertical>
              <Stack.Item>
                <LabeledList>
                  <LabeledList.Item label="Artist Name">
                    <Input
                      fluid
                      value={localArtist}
                      onChange={(e, value) => setLocalArtist(value || "")}
                      onEnter={() => {
                        if (localArtist?.trim()) {
                          act('set_artist_name', { value: localArtist });
                        }
                      }}
                      onBlur={() => {
                        if (localArtist?.trim()) {
                          act('set_artist_name', { value: localArtist });
                        }
                      }}
                      placeholder="Enter artist name..."
                    />
                  </LabeledList.Item>
                </LabeledList>
              </Stack.Item>
              <Stack.Item grow>
                <Box mb={1}>Tattoo Design:</Box>
                <Input.TextArea
                  fluid
                  height="100px"
                  value={localDesign}
                  onChange={(e, value) => setLocalDesign(value || "")}
                  onEnter={() => {
                    if (localDesign?.trim()) {
                      act('set_tattoo_design', { value: localDesign });
                    }
                  }}
                  onBlur={() => {
                    if (localDesign?.trim()) {
                      act('set_tattoo_design', { value: localDesign });
                    }
                  }}
                  placeholder="Describe the tattoo design..."
                />
              </Stack.Item>
              <Stack.Item>
                <Section title="Preview">
                  <Box
                    dangerouslySetInnerHTML={{
                      __html: preview_text || 'No preview available',
                    }}
                  />
                </Section>
              </Stack.Item>
              <Stack.Item>
                <Button
                  fluid
                  color="good"
                  icon="check"
                  disabled={!localArtist?.trim() || !localDesign?.trim() || ink_uses <= 0}
                  onClick={() => act('apply_tattoo')}
                >
                  Apply Tattoo (Costs 1 Ink)
                </Button>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>
      </Stack>
    );
  }

  return (
    <Section>
      <Box color="bad">Invalid state: {current_step}</Box>
    </Section>
  );
};
