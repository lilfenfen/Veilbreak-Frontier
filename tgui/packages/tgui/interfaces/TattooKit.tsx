// tgui/packages/tgui/interfaces/TattooKit.tsx

import { useState } from 'react';
import {
  Box,
  Button,
  ColorBox,
  Dimmer,
  Dropdown,
  Icon,
  Input,
  LabeledList,
  ProgressBar,
  Section,
  Stack,
  Tabs,
  TextArea,
} from 'tgui-core/components';
import { useBackend } from '../backend';
import { Window } from '../layouts';

interface TattooData {
  target_name: string;
  target_ref: string;
  ink_uses: number;
  max_ink_uses: number;
  applying: boolean;
  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string | null;
  ink_color: string;
  design_mode: boolean;
  debug_mode: boolean;
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
  layer_options: Record<string, string>;
  body_parts: BodyPart[];
  existing_tattoos: Tattoo[];
}

interface BodyPart {
  zone: string;
  name: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
}

interface Tattoo {
  artist: string;
  design: string;
  color: string;
  layer: number;
  font: string;
  flair: string | null;
  date_applied: string;
}

export const TattooKit = (props, context) => {
  const { act, data } = useBackend<TattooData>(context);
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    applying,
    artist_name = '',
    tattoo_design = '',
    selected_zone = '',
    selected_layer = 2,
    selected_font = 'PEN_FONT',
    selected_flair = null,
    ink_color = '#000000',
    design_mode = false,
    font_options = {},
    flair_options = {},
    layer_options = {},
    body_parts = [],
    existing_tattoos = [],
  } = data;

  const [searchText, setSearchText] = useState('');
  const [activeTab, setActiveTab] = useState(design_mode ? 'design' : 'parts');

  // Filter body parts based on search
  const filteredParts = body_parts.filter((part) =>
    part.name.toLowerCase().includes(searchText.toLowerCase()),
  );

  // Get current zone name
  const currentZoneName =
    body_parts.find((p) => p.zone === selected_zone)?.name || selected_zone;

  // Check if we can apply tattoo
  const canApply =
    selected_zone &&
    artist_name?.length > 0 &&
    tattoo_design?.length > 0 &&
    ink_uses > 0 &&
    !existing_tattoos.some((t) => t.layer === selected_layer);

  if (applying) {
    return (
      <Window width={400} height={200}>
        <Window.Content>
          <Dimmer>
            <Stack vertical textAlign="center">
              <Stack.Item>
                <Icon name="spinner" spin size={3} />
              </Stack.Item>
              <Stack.Item fontSize="1.2rem" bold>
                Applying Tattoo...
              </Stack.Item>
              <Stack.Item>Please hold still during the procedure.</Stack.Item>
            </Stack>
          </Dimmer>
        </Window.Content>
      </Window>
    );
  }

  return (
    <Window width={750} height={600} theme="abstract">
      <Window.Content>
        <Stack fill vertical>
          {/* Header */}
          <Stack.Item>
            <Section
              title="Tattoo Kit"
              buttons={
                <Box>
                  <ProgressBar
                    value={ink_uses}
                    minValue={0}
                    maxValue={max_ink_uses}
                    color={ink_uses > 0 ? 'good' : 'bad'}
                  >
                    Ink: {ink_uses}/{max_ink_uses}
                  </ProgressBar>
                </Box>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Target">
                  <Box color={target_name ? 'good' : 'average'} bold>
                    {target_name || 'None'}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Mode">
                  <Box color={design_mode ? 'blue' : 'green'}>
                    {design_mode ? 'Designing' : 'Selecting Body Part'}
                  </Box>
                </LabeledList.Item>
              </LabeledList>
            </Section>
          </Stack.Item>

          {/* Main Content */}
          <Stack.Item grow>
            <Section fill>
              <Tabs fluid>
                <Tabs.Tab
                  icon="user"
                  selected={activeTab === 'parts'}
                  onClick={() => {
                    setActiveTab('parts');
                    act('back_to_parts');
                  }}
                >
                  Body Parts
                </Tabs.Tab>
                <Tabs.Tab
                  icon="paint-brush"
                  selected={activeTab === 'design'}
                  disabled={!selected_zone}
                  onClick={() => setActiveTab('design')}
                >
                  {selected_zone ? `Design - ${currentZoneName}` : 'Design'}
                </Tabs.Tab>
              </Tabs>

              <Box mt={1}>
                {activeTab === 'parts' && (
                  <BodyPartTab
                    parts={filteredParts}
                    searchText={searchText}
                    onSearch={setSearchText}
                    onSelectPart={(zone) => {
                      act('select_zone', { zone });
                      setActiveTab('design');
                    }}
                  />
                )}

                {activeTab === 'design' && (
                  <DesignTab
                    artistName={artist_name}
                    design={tattoo_design}
                    zone={selected_zone}
                    zoneName={currentZoneName}
                    layer={selected_layer}
                    font={selected_font}
                    flair={selected_flair}
                    color={ink_color}
                    fontOptions={font_options}
                    flairOptions={flair_options}
                    layerOptions={layer_options}
                    existingTattoos={existing_tattoos}
                    canApply={canApply}
                    inkUses={ink_uses}
                    onBack={() => {
                      setActiveTab('parts');
                      act('back_to_parts');
                    }}
                    onApply={() => act('apply_tattoo')}
                    onArtistChange={(value) =>
                      act('set_artist', { artist: value })
                    }
                    onDesignChange={(value) =>
                      act('set_design', { design: value })
                    }
                    onFontChange={(value) => act('set_font', { font: value })}
                    onFlairChange={(value) =>
                      act('set_flair', { flair: value })
                    }
                    onLayerChange={(value) =>
                      act('set_layer', { layer: value })
                    }
                    onColorChange={(value) =>
                      act('set_color', { color: value })
                    }
                    onColorPick={() => act('pick_color')}
                  />
                )}
              </Box>
            </Section>
          </Stack.Item>
        </Stack>
      </Window.Content>
    </Window>
  );
};

// Body Parts Tab Component
const BodyPartTab = (props: {
  parts: BodyPart[];
  searchText: string;
  onSearch: (text: string) => void;
  onSelectPart: (zone: string) => void;
}) => {
  const { parts, searchText, onSearch, onSelectPart } = props;

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Input
          placeholder="Search body parts..."
          value={searchText}
          onChange={onSearch}
          fluid
        />
      </Stack.Item>
      <Stack.Item grow>
        <Section fill scrollable>
          {parts.length === 0 ? (
            <Box textAlign="center" color="label" py={4}>
              <Icon name="search" size={2} />
              <Box mt={1}>
                {searchText
                  ? 'No matching body parts'
                  : 'No accessible body parts'}
              </Box>
            </Box>
          ) : (
            <Stack vertical spacing={1}>
              {parts.map((part) => (
                <Stack.Item key={part.zone}>
                  <Button
                    fluid
                    color={part.covered ? 'average' : 'good'}
                    disabled={
                      part.covered || part.current_tattoos >= part.max_tattoos
                    }
                    onClick={() => onSelectPart(part.zone)}
                  >
                    <Stack align="center">
                      <Stack.Item>
                        <Icon
                          name={part.covered ? 'tshirt' : 'user-circle'}
                          mr={1}
                        />
                      </Stack.Item>
                      <Stack.Item grow textAlign="left">
                        <Box bold>{part.name}</Box>
                        <Box color="label" fontSize="0.8rem">
                          {part.current_tattoos}/{part.max_tattoos} tattoos
                          {part.covered && ' • Covered'}
                        </Box>
                      </Stack.Item>
                      <Stack.Item>
                        <Icon name="chevron-right" />
                      </Stack.Item>
                    </Stack>
                  </Button>
                </Stack.Item>
              ))}
            </Stack>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

// Design Tab Component
const DesignTab = (props: {
  artistName: string;
  design: string;
  zone: string;
  zoneName: string;
  layer: number;
  font: string;
  flair: string | null;
  color: string;
  fontOptions: Record<string, string>;
  flairOptions: Record<string, string>;
  layerOptions: Record<string, string>;
  existingTattoos: Tattoo[];
  canApply: boolean;
  inkUses: number;
  onBack: () => void;
  onApply: () => void;
  onArtistChange: (value: string) => void;
  onDesignChange: (value: string) => void;
  onFontChange: (value: string) => void;
  onFlairChange: (value: string | null) => void;
  onLayerChange: (value: number) => void;
  onColorChange: (value: string) => void;
  onColorPick: () => void;
}) => {
  const {
    artistName,
    design,
    zoneName,
    layer,
    font,
    flair,
    color,
    fontOptions,
    flairOptions,
    layerOptions,
    existingTattoos,
    canApply,
    inkUses,
    onBack,
    onApply,
    onArtistChange,
    onDesignChange,
    onFontChange,
    onFlairChange,
    onLayerChange,
    onColorChange,
    onColorPick,
  } = props;

  return (
    <Stack fill>
      {/* Left Panel - Design Controls */}
      <Stack.Item width="60%">
        <Stack fill vertical>
          {/* Basic Info */}
          <Stack.Item>
            <Section title={`Designing for ${zoneName}`}>
              <Stack>
                <Stack.Item grow>
                  <Button fluid onClick={onBack}>
                    <Icon name="arrow-left" /> Change Body Part
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    fluid
                    color="good"
                    disabled={!canApply}
                    onClick={onApply}
                    tooltip={
                      !canApply ? 'Complete all fields to apply tattoo' : null
                    }
                  >
                    <Icon name="paint-brush" /> Apply ({inkUses} left)
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Design Form */}
          <Stack.Item grow>
            <Section fill scrollable title="Tattoo Details">
              <Stack vertical spacing={1}>
                {/* Artist Name */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Artist Name
                    {artistName.includes('%s') && (
                      <Box as="span" color="yellow" ml={1}>
                        (Signature)
                      </Box>
                    )}
                  </Box>
                  <Input
                    value={artistName}
                    onChange={onArtistChange}
                    placeholder="Artist (use %s for signature)"
                    fluid
                  />
                </Stack.Item>

                {/* Tattoo Design */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Design Text
                  </Box>
                  <TextArea
                    value={design}
                    onChange={onDesignChange}
                    placeholder="Describe your tattoo design..."
                    height="80px"
                    fluid
                  />
                </Stack.Item>

                {/* Style Options */}
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box bold color="label" mb={0.5}>
                        Font
                      </Box>
                      <Dropdown
                        selected={font}
                        options={fontOptions}
                        onSelected={onFontChange}
                        width="100%"
                      />
                    </Stack.Item>
                    <Stack.Item grow ml={1}>
                      <Box bold color="label" mb={0.5}>
                        Style
                      </Box>
                      <Dropdown
                        selected={flair || 'null'}
                        options={flairOptions}
                        onSelected={(value) =>
                          onFlairChange(value === 'null' ? null : value)
                        }
                        width="100%"
                      />
                    </Stack.Item>
                  </Stack>
                </Stack.Item>

                {/* Layer Selection */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Layer
                  </Box>
                  <Stack>
                    {Object.entries(layerOptions).map(([key, label]) => {
                      const layerNum = parseInt(key);
                      const isTaken = existingTattoos.some(
                        (t) => t.layer === layerNum,
                      );
                      return (
                        <Stack.Item key={key} grow>
                          <Button
                            fluid
                            selected={layer === layerNum}
                            color={isTaken ? 'average' : 'default'}
                            onClick={() => {
                              if (isTaken) {
                                if (
                                  window.confirm(
                                    'Layer has existing tattoo. Overwrite?',
                                  )
                                ) {
                                  onLayerChange(layerNum);
                                }
                              } else {
                                onLayerChange(layerNum);
                              }
                            }}
                            tooltip={
                              isTaken ? 'Existing tattoo on this layer' : null
                            }
                          >
                            {label}
                            {isTaken && ' *'}
                          </Button>
                        </Stack.Item>
                      );
                    })}
                  </Stack>
                </Stack.Item>

                {/* Color Selection */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Ink Color
                  </Box>
                  <Stack align="center">
                    <Stack.Item>
                      <ColorBox color={color} />
                    </Stack.Item>
                    <Stack.Item grow>
                      <Input value={color} onChange={onColorChange} fluid />
                    </Stack.Item>
                    <Stack.Item>
                      <Button icon="palette" onClick={onColorPick}>
                        Pick
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Stack.Item>

      {/* Right Panel - Preview */}
      <Stack.Item width="40%">
        <Stack fill vertical>
          {/* Existing Tattoos */}
          <Stack.Item>
            <Section title="Existing Tattoos" fill={false}>
              {existingTattoos.length === 0 ? (
                <Box color="label" textAlign="center">
                  No tattoos on this area
                </Box>
              ) : (
                <Stack vertical spacing={0.5}>
                  {existingTattoos.map((tattoo, index) => (
                    <Stack.Item key={index}>
                      <Box
                        style={{
                          borderLeft: `3px solid ${tattoo.color}`,
                          padding: '4px 8px',
                          background: 'rgba(0,0,0,0.3)',
                        }}
                      >
                        <Box color={tattoo.color} fontSize="0.9rem">
                          "{tattoo.design}"
                        </Box>
                        <Box color="label" fontSize="0.7rem">
                          by {tattoo.artist} • Layer {tattoo.layer}
                        </Box>
                      </Box>
                    </Stack.Item>
                  ))}
                </Stack>
              )}
            </Section>
          </Stack.Item>

          {/* Preview */}
          <Stack.Item grow>
            <Section fill title="Preview" scrollable>
              {artistName && design ? (
                <Box
                  style={{
                    border: `2px solid ${color}`,
                    padding: '12px',
                    background: 'rgba(0,0,0,0.2)',
                    height: '100%',
                  }}
                >
                  <Box bold color={color} mb={1}>
                    {zoneName}
                  </Box>
                  <Box color={color} fontSize="1.1rem" mb={1}>
                    "{design}"
                  </Box>
                  <Box color="label" fontSize="0.9rem">
                    by {artistName.includes('%s') ? '[Your Name]' : artistName}
                  </Box>
                  <Box mt={2} color="label" fontSize="0.8rem">
                    <Stack>
                      <Stack.Item>Font: {fontOptions[font]}</Stack.Item>
                      <Stack.Item grow textAlign="right">
                        Style: {flairOptions[flair || 'null']}
                      </Stack.Item>
                    </Stack>
                    <Stack mt={0.5}>
                      <Stack.Item>Layer: {layerOptions[layer]}</Stack.Item>
                      <Stack.Item grow textAlign="right">
                        Color: <ColorBox color={color} />
                      </Stack.Item>
                    </Stack>
                  </Box>
                </Box>
              ) : (
                <Box textAlign="center" color="label" py={4}>
                  <Icon name="eye-slash" size={2} />
                  <Box mt={1}>Enter design details to see preview</Box>
                </Box>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );
};
