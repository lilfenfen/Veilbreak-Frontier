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
  Tooltip,
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
  is_signature: boolean;
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

  // Get current zone info
  const currentZone = body_parts.find((p) => p.zone === selected_zone);

  // Check application conditions
  const canApply =
    selected_zone &&
    artist_name?.length > 0 &&
    tattoo_design?.length > 0 &&
    ink_uses > 0 &&
    existing_tattoos.length < 3 &&
    !existing_tattoos.some((t) => t.layer === selected_layer);

  if (applying) {
    return (
      <Window width={400} height={200}>
        <Window.Content>
          <Dimmer>
            <Stack vertical textAlign="center" align="center">
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
    <Window width={900} height={700} theme="abstract">
      <Window.Content>
        <Stack fill vertical>
          {/* Header Section */}
          <Stack.Item>
            <Section
              title={
                <Stack align="center">
                  <Stack.Item>
                    <Icon name="palette" mr={1} />
                  </Stack.Item>
                  <Stack.Item>Professional Tattoo Kit</Stack.Item>
                </Stack>
              }
              buttons={
                <Stack>
                  <Stack.Item>
                    <Box textAlign="center">
                      <ProgressBar
                        value={ink_uses}
                        minValue={0}
                        maxValue={max_ink_uses}
                        color={
                          ink_uses > max_ink_uses * 0.5
                            ? 'good'
                            : ink_uses > max_ink_uses * 0.2
                              ? 'average'
                              : 'bad'
                        }
                      >
                        Ink: {ink_uses}/{max_ink_uses}
                      </ProgressBar>
                    </Box>
                  </Stack.Item>
                </Stack>
              }
            >
              <LabeledList>
                <LabeledList.Item label="Client">
                  <Box color={target_name ? 'good' : 'average'} bold>
                    {target_name || 'No target selected'}
                  </Box>
                </LabeledList.Item>
                <LabeledList.Item label="Status">
                  <Box color={design_mode ? 'blue' : 'green'}>
                    {design_mode
                      ? `Designing - ${currentZone?.name || selected_zone}`
                      : 'Selecting Body Part'}
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
                  icon="user-circle"
                  selected={activeTab === 'parts'}
                  onClick={() => {
                    setActiveTab('parts');
                    act('back_to_parts');
                  }}
                >
                  Body Parts ({body_parts.length})
                </Tabs.Tab>
                <Tabs.Tab
                  icon="paint-brush"
                  selected={activeTab === 'design'}
                  disabled={!selected_zone}
                  onClick={() => setActiveTab('design')}
                >
                  Tattoo Design {selected_zone && `- ${currentZone?.name}`}
                </Tabs.Tab>
              </Tabs>

              <Box mt={1}>
                {activeTab === 'parts' && (
                  <BodyPartSelection
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
                  <TattooDesigner
                    artistName={artist_name}
                    design={tattoo_design}
                    zone={selected_zone}
                    zoneName={currentZone?.name}
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

// Body Part Selection Component
const BodyPartSelection = (props: {
  parts: BodyPart[];
  searchText: string;
  onSearch: (text: string) => void;
  onSelectPart: (zone: string) => void;
}) => {
  const { parts, searchText, onSearch, onSelectPart } = props;

  // Group parts by availability
  const accessibleParts = parts.filter(
    (part) => !part.covered && part.current_tattoos < part.max_tattoos,
  );
  const coveredParts = parts.filter((part) => part.covered);
  const fullParts = parts.filter(
    (part) => part.current_tattoos >= part.max_tattoos,
  );

  const PartCard = ({
    part,
    status,
    color,
    icon,
  }: {
    part: BodyPart;
    status: string;
    color: string;
    icon: string;
  }) => (
    <Button
      fluid
      color={color}
      onClick={() => onSelectPart(part.zone)}
      disabled={status !== 'available'}
      tooltip={status !== 'available' ? `Cannot select: ${status}` : null}
    >
      <Stack align="center">
        <Stack.Item>
          <Icon name={icon} mr={1} />
        </Stack.Item>
        <Stack.Item grow textAlign="left">
          <Box bold>{part.name}</Box>
          <Box color="label" fontSize="0.8rem">
            {part.current_tattoos}/{part.max_tattoos} tattoos • {status}
          </Box>
        </Stack.Item>
        <Stack.Item>
          {status === 'available' && <Icon name="chevron-right" />}
          {status === 'covered' && <Icon name="tshirt" />}
          {status === 'full' && <Icon name="ban" />}
        </Stack.Item>
      </Stack>
    </Button>
  );

  return (
    <Stack fill vertical>
      <Stack.Item>
        <Input
          placeholder="Search body parts..."
          value={searchText}
          onChange={(e, value) => onSearch(value)}
          fluid
          icon="search"
        />
      </Stack.Item>

      <Stack.Item grow>
        <Stack fill>
          {/* Available Parts */}
          <Stack.Item grow={1}>
            <Section
              title={`Available (${accessibleParts.length})`}
              fill
              scrollable
              color="good"
            >
              {accessibleParts.length === 0 ? (
                <Box textAlign="center" color="label" py={4}>
                  <Icon name="search" size={2} />
                  <Box mt={1}>No available body parts</Box>
                  <Box fontSize="0.8rem">
                    Remove clothing or search different terms
                  </Box>
                </Box>
              ) : (
                <Stack vertical spacing={1}>
                  {accessibleParts.map((part) => (
                    <Stack.Item key={part.zone}>
                      <PartCard
                        part={part}
                        status="available"
                        color="good"
                        icon="user-circle"
                      />
                    </Stack.Item>
                  ))}
                </Stack>
              )}
            </Section>
          </Stack.Item>

          {/* Status Sections */}
          <Stack.Item width="50%">
            <Stack fill vertical>
              {/* Covered Parts */}
              <Stack.Item grow={1}>
                <Section
                  title={`Covered (${coveredParts.length})`}
                  fill
                  scrollable
                  color="average"
                >
                  {coveredParts.length === 0 ? (
                    <Box textAlign="center" color="label" py={2}>
                      <Icon name="check" />
                      <Box>All parts accessible</Box>
                    </Box>
                  ) : (
                    <Stack vertical spacing={1}>
                      {coveredParts.map((part) => (
                        <Stack.Item key={part.zone}>
                          <PartCard
                            part={part}
                            status="covered by clothing"
                            color="average"
                            icon="tshirt"
                          />
                        </Stack.Item>
                      ))}
                    </Stack>
                  )}
                </Section>
              </Stack.Item>

              {/* Full Parts */}
              <Stack.Item grow={1}>
                <Section
                  title={`Full (${fullParts.length})`}
                  fill
                  scrollable
                  color="bad"
                >
                  {fullParts.length === 0 ? (
                    <Box textAlign="center" color="label" py={2}>
                      <Icon name="smile" />
                      <Box>No full areas</Box>
                    </Box>
                  ) : (
                    <Stack vertical spacing={1}>
                      {fullParts.map((part) => (
                        <Stack.Item key={part.zone}>
                          <PartCard
                            part={part}
                            status="maximum tattoos reached"
                            color="bad"
                            icon="ban"
                          />
                        </Stack.Item>
                      ))}
                    </Stack>
                  )}
                </Section>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );
};

// Tattoo Designer Component
const TattooDesigner = (props: {
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

  const isSignature = artistName.includes('%s');

  return (
    <Stack fill>
      {/* Design Panel */}
      <Stack.Item width="65%">
        <Stack fill vertical>
          {/* Header Actions */}
          <Stack.Item>
            <Section>
              <Stack>
                <Stack.Item>
                  <Button onClick={onBack}>
                    <Icon name="arrow-left" /> Back to Body Parts
                  </Button>
                </Stack.Item>
                <Stack.Item grow textAlign="center">
                  <Box bold fontSize="1.2rem">
                    Designing for {zoneName}
                  </Box>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    color="good"
                    disabled={!canApply}
                    onClick={onApply}
                    tooltip={
                      !canApply
                        ? 'Complete all required fields and ensure ink is available'
                        : 'Apply tattoo to selected body part'
                    }
                    icon="paint-brush"
                  >
                    Apply Tattoo ({inkUses} uses left)
                  </Button>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Design Form */}
          <Stack.Item grow>
            <Section fill scrollable title="Tattoo Design">
              <Stack vertical spacing={1.5}>
                {/* Artist Name with Signature Detection */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Artist Name
                    {isSignature && (
                      <Box as="span" color="blue" ml={1}>
                        <Icon name="signature" /> Signature Format
                      </Box>
                    )}
                  </Box>
                  <Input
                    value={artistName}
                    onChange={(e, value) => onArtistChange(value)}
                    placeholder="Enter artist name (use %s for automatic signature)"
                    fluid
                  />
                  {isSignature && (
                    <Box color="blue" fontSize="0.8rem" mt={0.5}>
                      Will be replaced with your name during application
                    </Box>
                  )}
                </Stack.Item>

                {/* Tattoo Design */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Tattoo Design
                  </Box>
                  <TextArea
                    value={design}
                    onChange={(e, value) => onDesignChange(value)}
                    placeholder="Describe your tattoo design in detail..."
                    height="120px"
                    fluid
                  />
                  <Box color="label" fontSize="0.8rem" mt={0.5}>
                    Supports emojis like :heart: :star: :smile: and text
                    formatting
                  </Box>
                </Stack.Item>

                {/* Style Options */}
                <Stack.Item>
                  <Stack>
                    <Stack.Item grow>
                      <Box bold color="label" mb={0.5}>
                        Writing Instrument
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
                        Text Flair
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

                {/* Layer Selection with Visual Indicators */}
                <Stack.Item>
                  <Box bold color="label" mb={0.5}>
                    Layer Placement
                  </Box>
                  <Stack>
                    {Object.entries(layerOptions).map(([key, label]) => {
                      const layerNum = parseInt(key);
                      const isTaken = existingTattoos.some(
                        (t) => t.layer === layerNum,
                      );
                      const isSelected = layer === layerNum;

                      return (
                        <Stack.Item key={key} grow>
                          <Tooltip
                            content={
                              isTaken
                                ? `Layer occupied by existing tattoo`
                                : `Place tattoo on ${label.toLowerCase()} layer`
                            }
                          >
                            <Button
                              fluid
                              selected={isSelected}
                              color={
                                isTaken
                                  ? 'bad'
                                  : isSelected
                                    ? 'good'
                                    : 'default'
                              }
                              onClick={() => {
                                if (isTaken) {
                                  if (
                                    window.confirm(
                                      'This layer already has a tattoo. Applying a new one will replace it. Continue?',
                                    )
                                  ) {
                                    onLayerChange(layerNum);
                                  }
                                } else {
                                  onLayerChange(layerNum);
                                }
                              }}
                            >
                              <Stack vertical align="center">
                                <Stack.Item>{isTaken ? '⚠️' : '🎨'}</Stack.Item>
                                <Stack.Item fontSize="0.8rem">
                                  {label}
                                </Stack.Item>
                                {isTaken && (
                                  <Stack.Item fontSize="0.7rem" color="label">
                                    Occupied
                                  </Stack.Item>
                                )}
                              </Stack>
                            </Button>
                          </Tooltip>
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
                      <Input
                        value={color}
                        onChange={(e, value) => onColorChange(value)}
                        placeholder="#000000"
                        fluid
                      />
                    </Stack.Item>
                    <Stack.Item>
                      <Button
                        icon="palette"
                        onClick={onColorPick}
                        tooltip="Open color picker"
                      >
                        Pick Color
                      </Button>
                    </Stack.Item>
                  </Stack>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Stack.Item>

      {/* Preview Panel */}
      <Stack.Item width="35%">
        <Stack fill vertical>
          {/* Existing Tattoos */}
          <Stack.Item>
            <Section
              title={`Existing Tattoos (${existingTattoos.length}/3)`}
              fill={false}
              buttons={
                <Box color={existingTattoos.length >= 3 ? 'bad' : 'good'}>
                  {existingTattoos.length}/3 slots used
                </Box>
              }
            >
              {existingTattoos.length === 0 ? (
                <Box textAlign="center" color="label" py={3}>
                  <Icon name="plus-circle" size={2} />
                  <Box mt={1}>No tattoos yet</Box>
                  <Box fontSize="0.8rem">This area is blank</Box>
                </Box>
              ) : (
                <Stack vertical spacing={1}>
                  {existingTattoos.map((tattoo, index) => (
                    <Stack.Item key={index}>
                      <Box
                        style={{
                          borderLeft: `4px solid ${tattoo.color}`,
                          padding: '8px',
                          background: 'rgba(0,0,0,0.3)',
                          borderRadius: '4px',
                        }}
                      >
                        <Box
                          color={tattoo.color}
                          style={{
                            fontFamily:
                              tattoo.font === 'CRAYON_FONT'
                                ? 'Comic Sans MS, cursive'
                                : 'inherit',
                            fontWeight: 'bold',
                          }}
                        >
                          "{tattoo.design}"
                        </Box>
                        <Stack mt={0.5}>
                          <Stack.Item grow fontSize="0.8rem" color="label">
                            by {tattoo.artist}
                          </Stack.Item>
                          <Stack.Item fontSize="0.7rem" color="label">
                            Layer {tattoo.layer}
                          </Stack.Item>
                        </Stack>
                        {tattoo.flair && (
                          <Box fontSize="0.7rem" color="blue">
                            Style: {flairOptions[tattoo.flair]}
                          </Box>
                        )}
                      </Box>
                    </Stack.Item>
                  ))}
                </Stack>
              )}
            </Section>
          </Stack.Item>

          {/* Live Preview */}
          <Stack.Item grow>
            <Section fill title="Live Preview" scrollable>
              {artistName || design ? (
                <Box
                  style={{
                    border: `3px solid ${color}`,
                    padding: '16px',
                    background: 'rgba(0,0,0,0.2)',
                    borderRadius: '8px',
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                  }}
                >
                  {/* Body Part Header */}
                  <Box
                    textAlign="center"
                    bold
                    fontSize="1.1rem"
                    color={color}
                    mb={2}
                    style={{
                      borderBottom: `1px solid ${color}`,
                      paddingBottom: '8px',
                    }}
                  >
                    {zoneName}
                  </Box>

                  {/* Tattoo Design */}
                  <Box
                    flexGrow={1}
                    textAlign="center"
                    style={{
                      display: 'flex',
                      flexDirection: 'column',
                      justifyContent: 'center',
                      minHeight: '100px',
                    }}
                  >
                    <Box
                      fontSize="1.2rem"
                      color={color}
                      style={{
                        fontFamily:
                          font === 'CRAYON_FONT'
                            ? 'Comic Sans MS, cursive'
                            : font === 'FOUNTAIN_PEN_FONT'
                              ? 'Brush Script MT, cursive'
                              : 'inherit',
                        fontWeight: 'bold',
                        lineHeight: '1.4',
                      }}
                    >
                      "{design || 'Your design will appear here'}"
                    </Box>
                  </Box>

                  {/* Artist Signature */}
                  <Box
                    textAlign="right"
                    color={color}
                    fontSize="0.9rem"
                    mt={2}
                    style={{
                      borderTop: `1px solid ${color}`,
                      paddingTop: '8px',
                    }}
                  >
                    —{' '}
                    {isSignature
                      ? 'Your Signature'
                      : artistName || 'Unknown Artist'}
                  </Box>

                  {/* Style Details */}
                  <Box mt={2} color="label" fontSize="0.8rem">
                    <Stack>
                      <Stack.Item>
                        <Icon name="pen" /> {fontOptions[font]}
                      </Stack.Item>
                      <Stack.Item grow textAlign="center">
                        <Icon name="layer-group" /> {layerOptions[layer]}
                      </Stack.Item>
                      <Stack.Item>
                        {flair && flair !== 'null' ? (
                          <>
                            <Icon name="star" /> {flairOptions[flair]}
                          </>
                        ) : (
                          <>
                            <Icon name="minus" /> No Flair
                          </>
                        )}
                      </Stack.Item>
                    </Stack>
                  </Box>
                </Box>
              ) : (
                <Box
                  textAlign="center"
                  color="label"
                  py={4}
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    justifyContent: 'center',
                    height: '100%',
                  }}
                >
                  <Icon name="eye-slash" size={3} />
                  <Box mt={2} fontSize="1.1rem">
                    Design Preview
                  </Box>
                  <Box mt={1} fontSize="0.9rem">
                    Enter artist name and design
                  </Box>
                  <Box mt={1} fontSize="0.8rem">
                    to see live preview
                  </Box>
                </Box>
              )}
            </Section>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );
};
