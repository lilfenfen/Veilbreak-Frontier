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
  Table,
  Tabs,
  TextArea,
  Tooltip,
} from 'tgui-core/components';
import { useBackend, useSharedState } from '../backend';
import { Window } from '../layouts';

interface TattooData {
  // Target information
  target_name: string;
  target_ref: string;

  // Kit status
  ink_uses: number;
  max_ink_uses: number;
  applying: boolean;

  // Current design
  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string | null;
  ink_color: string;
  design_mode: boolean;
  debug_mode: boolean;

  // Available options
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
  layer_options: Record<string, string>;

  // Body parts data
  body_parts: BodyPart[];

  // Existing tattoos for current zone
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
  is_signature: boolean;
  font: string;
  flair: string | null;
  date_applied: string;
}

export const TattooKit = (props, context) => {
  const { act, data } = useBackend<TattooData>(context);
  const {
    target_name,
    target_ref,
    ink_uses,
    max_ink_uses,
    applying,
    artist_name,
    tattoo_design,
    selected_zone,
    selected_layer,
    selected_font,
    selected_flair,
    ink_color,
    design_mode,
    debug_mode,
    font_options,
    flair_options,
    layer_options,
    body_parts,
    existing_tattoos,
  } = data;

  const [searchItem, setSearchItem] = useState('');
  const [activeTab, setActiveTab] = useSharedState(
    context,
    'activeTab',
    design_mode ? 'design' : 'parts',
  );

  // Calculate ink percentage for progress bar
  const ink_percent = max_ink_uses ? (ink_uses / max_ink_uses) * 100 : 0;

  // Get current zone display name
  const getZoneDisplayName = (zone: string) => {
    const part = body_parts.find((part) => part.zone === zone);
    return part ? part.name : 'Unknown Location';
  };

  // Check if we can apply tattoo
  const canApply = () => {
    return (
      target_ref &&
      selected_zone &&
      artist_name?.length > 0 &&
      tattoo_design?.length > 0 &&
      ink_uses > 0 &&
      !isLayerTaken()
    );
  };

  // Check if selected layer is already taken
  const isLayerTaken = () => {
    return existing_tattoos.some((tattoo) => tattoo.layer === selected_layer);
  };

  return (
    <Window
      width={800}
      height={700}
      theme="abstract"
      title={`Tattoo Kit - ${target_name || 'No Target'}`}
    >
      <Window.Content>
        {applying && (
          <Dimmer>
            <Stack vertical textAlign="center">
              <Stack.Item>
                <Icon name="spinner" spin size={4} />
              </Stack.Item>
              <Stack.Item fontSize="1.5rem" bold>
                Applying Tattoo...
              </Stack.Item>
              <Stack.Item>
                Please hold still while the tattoo is being applied.
              </Stack.Item>
            </Stack>
          </Dimmer>
        )}
        <Stack vertical fill>
          {/* Header Section */}
          <Stack.Item>
            <Section
              title={
                <Stack align="center">
                  <Stack.Item>
                    <Icon name="paint-brush" />
                  </Stack.Item>
                  <Stack.Item>Professional Tattoo Kit</Stack.Item>
                </Stack>
              }
              buttons={
                <Stack>
                  <Stack.Item>
                    <Button
                      icon="bug"
                      color={debug_mode ? 'good' : 'transparent'}
                      onClick={() => act('toggle_debug')}
                      tooltip="Toggle debug mode"
                    >
                      Debug
                    </Button>
                  </Stack.Item>
                </Stack>
              }
            >
              <Stack align="center">
                <Stack.Item grow>
                  <LabeledList>
                    <LabeledList.Item label="Target">
                      <Box color={target_name ? 'good' : 'average'} bold>
                        {target_name || 'No Target Selected'}
                      </Box>
                    </LabeledList.Item>
                    <LabeledList.Item label="Status">
                      <Box color={design_mode ? 'blue' : 'green'}>
                        {design_mode ? 'Design Mode' : 'Part Selection'}
                      </Box>
                    </LabeledList.Item>
                  </LabeledList>
                </Stack.Item>
                <Stack.Item>
                  <LabeledList>
                    <LabeledList.Item label="Ink Remaining">
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
                        {ink_uses}/{max_ink_uses}
                      </ProgressBar>
                    </LabeledList.Item>
                  </LabeledList>
                </Stack.Item>
              </Stack>
            </Section>
          </Stack.Item>

          {/* Main Content Area */}
          <Stack.Item grow>
            <Section fill>
              <Tabs fluid>
                <Tabs.Tab
                  icon="list"
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
                  onClick={() => {
                    if (selected_zone) {
                      setActiveTab('design');
                    }
                  }}
                  tooltip={!selected_zone ? 'Select a body part first' : null}
                  disabled={!selected_zone}
                >
                  Tattoo Design
                </Tabs.Tab>
              </Tabs>

              <Stack mt={1} fill>
                {activeTab === 'parts' && (
                  <BodyPartSelection
                    body_parts={body_parts}
                    searchItem={searchItem}
                    setSearchItem={setSearchItem}
                    onSelectZone={(zone) => {
                      act('select_zone', { zone });
                      setActiveTab('design');
                    }}
                  />
                )}

                {activeTab === 'design' && (
                  <DesignInterface
                    artist_name={artist_name}
                    tattoo_design={tattoo_design}
                    selected_zone={selected_zone}
                    selected_layer={selected_layer}
                    selected_font={selected_font}
                    selected_flair={selected_flair}
                    ink_color={ink_color}
                    font_options={font_options}
                    flair_options={flair_options}
                    layer_options={layer_options}
                    existing_tattoos={existing_tattoos}
                    ink_uses={ink_uses}
                    canApply={canApply()}
                    isLayerTaken={isLayerTaken()}
                    getZoneDisplayName={getZoneDisplayName}
                    onBack={() => {
                      setActiveTab('parts');
                      act('back_to_parts');
                    }}
                    onApply={() => act('apply_tattoo')}
                    onSetArtist={(value) =>
                      act('set_artist', { artist: value })
                    }
                    onSetDesign={(value) =>
                      act('set_design', { design: value })
                    }
                    onSetFont={(value) => act('set_font', { font: value })}
                    onSetFlair={(value) => act('set_flair', { flair: value })}
                    onSetLayer={(value) => act('set_layer', { layer: value })}
                    onSetColor={(value) => act('set_color', { color: value })}
                    onPickColor={() => act('pick_color')}
                  />
                )}
              </Stack>
            </Section>
          </Stack.Item>

          {/* Debug Information */}
          {debug_mode && (
            <Stack.Item>
              <DebugInfo
                selected_zone={selected_zone}
                design_mode={design_mode}
                artist_name={artist_name}
                tattoo_design={tattoo_design}
                canApply={canApply()}
                isLayerTaken={isLayerTaken()}
              />
            </Stack.Item>
          )}
        </Stack>
      </Window.Content>
    </Window>
  );
};

interface BodyPartSelectionProps {
  body_parts: BodyPart[];
  searchItem: string;
  setSearchItem: (value: string) => void;
  onSelectZone: (zone: string) => void;
}

const BodyPartSelection = (props: BodyPartSelectionProps) => {
  const { body_parts, searchItem, setSearchItem, onSelectZone } = props;

  const filteredParts = body_parts.filter((part) =>
    part.name.toLowerCase().includes(searchItem.toLowerCase()),
  );

  return (
    <Stack.Item grow>
      <Stack vertical fill>
        <Stack.Item>
          <Input
            autoFocus
            placeholder="Search body parts..."
            value={searchItem}
            onChange={setSearchItem}
            fluid
          />
        </Stack.Item>
        <Stack.Item grow>
          <Section fill scrollable>
            <Table>
              {filteredParts.map((part) => (
                <Table.Row key={part.zone} className="candystripe">
                  <Table.Cell collapsing>
                    <Icon
                      name={part.covered ? 'tshirt' : 'user'}
                      color={part.covered ? 'average' : 'good'}
                    />
                  </Table.Cell>
                  <Table.Cell bold>{part.name}</Table.Cell>
                  <Table.Cell collapsing color="label">
                    {part.current_tattoos}/{part.max_tattoos}
                  </Table.Cell>
                  <Table.Cell collapsing>
                    <Button
                      icon="paint-brush"
                      color={part.covered ? 'average' : 'good'}
                      disabled={
                        part.covered || part.current_tattoos >= part.max_tattoos
                      }
                      tooltip={
                        part.covered
                          ? 'This body part is covered by clothing'
                          : part.current_tattoos >= part.max_tattoos
                            ? 'Maximum tattoos reached for this part'
                            : 'Design a tattoo for this body part'
                      }
                      onClick={() => onSelectZone(part.zone)}
                    >
                      Select
                    </Button>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          </Section>
        </Stack.Item>
      </Stack>
    </Stack.Item>
  );
};

interface DesignInterfaceProps {
  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string | null;
  ink_color: string;
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
  layer_options: Record<string, string>;
  existing_tattoos: Tattoo[];
  ink_uses: number;
  canApply: boolean;
  isLayerTaken: boolean;
  getZoneDisplayName: (zone: string) => string;
  onBack: () => void;
  onApply: () => void;
  onSetArtist: (value: string) => void;
  onSetDesign: (value: string) => void;
  onSetFont: (value: string) => void;
  onSetFlair: (value: string | null) => void;
  onSetLayer: (value: number) => void;
  onSetColor: (value: string) => void;
  onPickColor: () => void;
}

const DesignInterface = (props: DesignInterfaceProps) => {
  const {
    artist_name,
    tattoo_design,
    selected_zone,
    selected_layer,
    selected_font,
    selected_flair,
    ink_color,
    font_options,
    flair_options,
    layer_options,
    existing_tattoos,
    ink_uses,
    canApply,
    isLayerTaken,
    getZoneDisplayName,
    onBack,
    onApply,
    onSetArtist,
    onSetDesign,
    onSetFont,
    onSetFlair,
    onSetLayer,
    onSetColor,
    onPickColor,
  } = props;

  return (
    <Stack.Item grow>
      <Stack fill>
        {/* Design Controls */}
        <Stack.Item width="50%">
          <Section fill scrollable title="Design Controls">
            <Stack vertical>
              {/* Artist Name */}
              <Stack.Item>
                <Box bold color="label" mb={1}>
                  Artist Name
                  {artist_name?.includes('%s') && (
                    <Box as="span" color="yellow" ml={1}>
                      (Signature Format)
                    </Box>
                  )}
                </Box>
                <Input
                  fluid
                  value={artist_name}
                  onChange={(e, value) => onSetArtist(value)}
                  placeholder="Artist name (use %s for signature)"
                />
                <Box color="label" fontSize="0.8rem" mt={0.5}>
                  Use %s in name for signature formatting
                </Box>
              </Stack.Item>

              {/* Tattoo Design */}
              <Stack.Item mt={2}>
                <Box bold color="label" mb={1}>
                  Tattoo Design
                </Box>
                <TextArea
                  fluid
                  height="100px"
                  value={tattoo_design}
                  onChange={(e, value) => onSetDesign(value)}
                  placeholder="Describe the tattoo design (supports :emoji: shortcodes)"
                />
                <Box color="label" fontSize="0.8rem" mt={0.5}>
                  Supports emoji shortcodes like :heart: :smile: :star: etc.
                </Box>
              </Stack.Item>

              {/* Style Options */}
              <Stack.Item mt={2}>
                <Stack>
                  <Stack.Item grow>
                    <Box bold color="label" mb={1}>
                      Font Style
                    </Box>
                    <Dropdown
                      width="100%"
                      selected={selected_font}
                      options={font_options}
                      onSelected={onSetFont}
                    />
                  </Stack.Item>
                  <Stack.Item grow ml={1}>
                    <Box bold color="label" mb={1}>
                      Text Flair
                    </Box>
                    <Dropdown
                      width="100%"
                      selected={selected_flair || 'null'}
                      options={flair_options}
                      onSelected={(value) =>
                        onSetFlair(value === 'null' ? null : value)
                      }
                    />
                  </Stack.Item>
                </Stack>
              </Stack.Item>

              {/* Layer Selection */}
              <Stack.Item mt={2}>
                <Box bold color="label" mb={1}>
                  Tattoo Layer
                </Box>
                <Stack>
                  {Object.entries(layer_options).map(([key, label]) => {
                    const layerNum = parseInt(key);
                    const isTaken = existing_tattoos.some(
                      (t) => t.layer === layerNum,
                    );
                    return (
                      <Stack.Item key={key} grow>
                        <Button
                          fluid
                          color={
                            selected_layer === layerNum
                              ? isTaken
                                ? 'average'
                                : 'good'
                              : isTaken
                                ? 'average'
                                : 'default'
                          }
                          onClick={() => {
                            if (isTaken) {
                              if (
                                window.confirm(
                                  'This layer already has a tattoo. Are you sure you want to select it?',
                                )
                              ) {
                                onSetLayer(layerNum);
                              }
                            } else {
                              onSetLayer(layerNum);
                            }
                          }}
                          tooltip={
                            isTaken
                              ? 'This layer already has a tattoo'
                              : `Select ${label} layer`
                          }
                        >
                          {label}
                          {isTaken && ' (Taken)'}
                        </Button>
                      </Stack.Item>
                    );
                  })}
                </Stack>
              </Stack.Item>

              {/* Color Selection */}
              <Stack.Item mt={2}>
                <Box bold color="label" mb={1}>
                  Ink Color
                </Box>
                <Stack align="center">
                  <Stack.Item>
                    <ColorBox color={ink_color} />
                  </Stack.Item>
                  <Stack.Item grow>
                    <Input
                      value={ink_color}
                      onChange={(e, value) => onSetColor(value)}
                    />
                  </Stack.Item>
                  <Stack.Item>
                    <Button icon="palette" onClick={onPickColor}>
                      Pick
                    </Button>
                  </Stack.Item>
                </Stack>
              </Stack.Item>
            </Stack>
          </Section>
        </Stack.Item>

        {/* Preview Panel */}
        <Stack.Item width="50%">
          <PreviewPanel
            artist_name={artist_name}
            tattoo_design={tattoo_design}
            selected_zone={selected_zone}
            selected_layer={selected_layer}
            selected_font={selected_font}
            selected_flair={selected_flair}
            ink_color={ink_color}
            existing_tattoos={existing_tattoos}
            ink_uses={ink_uses}
            canApply={canApply}
            getZoneDisplayName={getZoneDisplayName}
            onBack={onBack}
            onApply={onApply}
            font_options={font_options}
            flair_options={flair_options}
            layer_options={layer_options}
          />
        </Stack.Item>
      </Stack>
    </Stack.Item>
  );
};

interface PreviewPanelProps {
  artist_name: string;
  tattoo_design: string;
  selected_zone: string;
  selected_layer: number;
  selected_font: string;
  selected_flair: string | null;
  ink_color: string;
  existing_tattoos: Tattoo[];
  ink_uses: number;
  canApply: boolean;
  getZoneDisplayName: (zone: string) => string;
  onBack: () => void;
  onApply: () => void;
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
  layer_options: Record<string, string>;
}

const PreviewPanel = (props: PreviewPanelProps) => {
  const {
    artist_name,
    tattoo_design,
    selected_zone,
    selected_layer,
    selected_font,
    selected_flair,
    ink_color,
    existing_tattoos,
    ink_uses,
    canApply,
    getZoneDisplayName,
    onBack,
    onApply,
    font_options,
    flair_options,
    layer_options,
  } = props;

  return (
    <Stack vertical fill>
      {/* Action Buttons */}
      <Stack.Item>
        <Section>
          <Stack>
            <Stack.Item>
              <Button icon="arrow-left" onClick={onBack}>
                Back to Parts
              </Button>
            </Stack.Item>
            <Stack.Item grow>
              <Button
                fluid
                fontSize="1.2rem"
                height="3rem"
                color={canApply ? 'good' : 'average'}
                disabled={!canApply}
                onClick={onApply}
                tooltip={
                  !canApply
                    ? 'Fill out all fields and ensure ink is available'
                    : 'Apply the tattoo design'
                }
              >
                <Icon name="paint-brush" mr={1} />
                Apply Tattoo ({ink_uses} use{ink_uses !== 1 ? 's' : ''} left)
              </Button>
            </Stack.Item>
          </Stack>
        </Section>
      </Stack.Item>

      {/* Existing Tattoos */}
      <Stack.Item>
        <Section
          title={`Existing Tattoos - ${getZoneDisplayName(selected_zone)}`}
        >
          {existing_tattoos.length > 0 ? (
            <Table>
              {existing_tattoos.map((tattoo, index) => (
                <Table.Row key={index} className="candystripe">
                  <Table.Cell
                    style={{
                      borderLeft: `3px solid ${tattoo.color}`,
                    }}
                  >
                    <Box color={tattoo.color}>
                      &ldquo;{tattoo.design}&rdquo;
                    </Box>
                    <Box color="label" fontSize="0.8rem">
                      by {tattoo.artist} | Layer: {tattoo.layer} |{' '}
                      {tattoo.date_applied}
                    </Box>
                  </Table.Cell>
                </Table.Row>
              ))}
            </Table>
          ) : (
            <Box textAlign="center" color="label" py={2}>
              No existing tattoos on this body part
            </Box>
          )}
        </Section>
      </Stack.Item>

      {/* New Design Preview */}
      <Stack.Item grow>
        <Section fill title="Design Preview" scrollable>
          {artist_name && tattoo_design ? (
            <Box
              p={2}
              style={{
                border: `2px dashed ${ink_color}`,
                background: `rgba(${hexToRgb(ink_color)}, 0.1)`,
                borderRadius: '4px',
              }}
            >
              <Box bold color={ink_color} mb={1}>
                New Tattoo Preview
              </Box>
              <Box color={ink_color} fontFamily="monospace" mb={1}>
                - {getZoneDisplayName(selected_zone)}: &ldquo;
                <span
                  dangerouslySetInnerHTML={{
                    __html: tattoo_design,
                  }}
                />
                &rdquo; (by {artist_name.includes('%s') ? 'You' : artist_name})
              </Box>
              <LabeledList>
                <LabeledList.Item label="Layer">
                  {layer_options[selected_layer]}
                </LabeledList.Item>
                <LabeledList.Item label="Font">
                  {font_options[selected_font]}
                </LabeledList.Item>
                <LabeledList.Item label="Flair">
                  {flair_options[selected_flair || 'null']}
                </LabeledList.Item>
                <LabeledList.Item label="Color">
                  <ColorBox color={ink_color} /> {ink_color}
                </LabeledList.Item>
              </LabeledList>
            </Box>
          ) : (
            <Box textAlign="center" color="label" py={4}>
              <Icon name="paint-brush" size={3} opacity={0.5} />
              <Box mt={2}>Enter artist name and design to see preview</Box>
            </Box>
          )}
        </Section>
      </Stack.Item>
    </Stack>
  );
};

interface DebugInfoProps {
  selected_zone: string;
  design_mode: boolean;
  artist_name: string;
  tattoo_design: string;
  canApply: boolean;
  isLayerTaken: boolean;
}

const DebugInfo = (props: DebugInfoProps) => {
  const {
    selected_zone,
    design_mode,
    artist_name,
    tattoo_design,
    canApply,
    isLayerTaken,
  } = props;

  return (
    <Section title="Debug Information" backgroundColor="rgba(255,0,0,0.1)">
      <LabeledList>
        <LabeledList.Item label="Selected Zone">
          {selected_zone}
        </LabeledList.Item>
        <LabeledList.Item label="Design Mode">
          {design_mode ? 'True' : 'False'}
        </LabeledList.Item>
        <LabeledList.Item label="Artist Length">
          {artist_name?.length || 0}
        </LabeledList.Item>
        <LabeledList.Item label="Design Length">
          {tattoo_design?.length || 0}
        </LabeledList.Item>
        <LabeledList.Item label="Layer Taken">
          {isLayerTaken ? 'True' : 'False'}
        </LabeledList.Item>
        <LabeledList.Item label="Can Apply">
          {canApply ? 'True' : 'False'}
        </LabeledList.Item>
      </LabeledList>
    </Section>
  );
};

// Helper function to convert hex to RGB
const hexToRgb = (hex: string): string => {
  if (!hex || hex.length !== 7) return '0,0,0';
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `${r},${g},${b}`;
};
