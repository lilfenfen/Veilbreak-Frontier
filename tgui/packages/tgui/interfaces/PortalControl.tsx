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
  font_options: Record<string, string>;
  flair_options: Record<string, string>;
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
    body_parts = [],
    existing_tattoos = [],
  } = data;

  const [searchText, setSearchText] = useState('');
  const [activeTab, setActiveTab] = useState(design_mode ? 'design' : 'parts');

  if (applying) {
    return (
      <Window width={400} height={200}>
        <Window.Content>
          <Dimmer>
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                height: '100%',
                textAlign: 'center',
              }}
            >
              <Icon name="spinner" spin size={3} />
              <div
                style={{
                  fontSize: '1.2rem',
                  fontWeight: 'bold',
                  margin: '1rem 0',
                }}
              >
                Applying Tattoo...
              </div>
              <div>Please hold still during the procedure.</div>
            </div>
          </Dimmer>
        </Window.Content>
      </Window>
    );
  }

  return (
    <Window width={950} height={700} theme="abstract">
      <Window.Content
        style={{
          display: 'flex',
          flexDirection: 'column',
          height: '100%',
        }}
      >
        {/* Header Section */}
        <Section
          style={{ flexShrink: 0 }}
          title={
            <div
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
              }}
            >
              <Icon name="palette" />
              Professional Tattoo Studio
            </div>
          }
          buttons={
            <div style={{ minWidth: '200px' }}>
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
            </div>
          }
        >
          <LabeledList
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr',
              gap: '1rem',
            }}
          >
            <LabeledList.Item label="Client">
              <Box color={target_name ? 'good' : 'average'} bold>
                {target_name || 'No target selected'}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Mode">
              <Box color={design_mode ? 'blue' : 'green'}>
                {design_mode ? 'Designing' : 'Selecting Body Part'}
              </Box>
            </LabeledList.Item>
          </LabeledList>
        </Section>

        {/* Main Content */}
        <Section
          fill
          style={{
            display: 'flex',
            flexDirection: 'column',
            minHeight: 0,
            flex: 1,
          }}
        >
          <Tabs fluid style={{ flexShrink: 0 }}>
            <Tabs.Tab
              icon="user-circle"
              selected={activeTab === 'parts'}
              onClick={() => {
                setActiveTab('parts');
                act('back_to_parts');
              }}
            >
              Body Canvas
            </Tabs.Tab>
            <Tabs.Tab
              icon="paint-brush"
              selected={activeTab === 'design'}
              disabled={!selected_zone}
              onClick={() => setActiveTab('design')}
            >
              Tattoo Design
            </Tabs.Tab>
          </Tabs>

          <div
            style={{
              flex: 1,
              minHeight: 0,
              marginTop: '0.5rem',
            }}
          >
            {activeTab === 'parts' && (
              <BodyCanvas
                bodyParts={body_parts}
                searchText={searchText}
                onSearch={setSearchText}
                onSelectPart={(zone) => {
                  act('select_zone', { zone });
                  setActiveTab('design');
                }}
              />
            )}

            {activeTab === 'design' && (
              <DesignStudio
                artistName={artist_name}
                design={tattoo_design}
                selectedZone={selected_zone}
                bodyParts={body_parts}
                layer={selected_layer}
                font={selected_font}
                flair={selected_flair}
                color={ink_color}
                fontOptions={font_options}
                flairOptions={flair_options}
                existingTattoos={existing_tattoos}
                canApply={
                  selected_zone &&
                  artist_name?.trim().length > 0 &&
                  tattoo_design?.trim().length > 0 &&
                  ink_uses > 0
                }
                inkUses={ink_uses}
                onBack={() => {
                  setActiveTab('parts');
                  act('back_to_parts');
                }}
                onApply={() => act('apply_tattoo')}
                onArtistChange={(value) => act('set_artist', { artist: value })}
                onDesignChange={(value) => act('set_design', { design: value })}
                onFontChange={(value) => act('set_font', { font: value })}
                onFlairChange={(value) => act('set_flair', { flair: value })}
                onLayerChange={(value) => act('set_layer', { layer: value })}
                onColorChange={(value) => act('set_color', { color: value })}
                onColorPick={() => act('pick_color')}
              />
            )}
          </div>
        </Section>
      </Window.Content>
    </Window>
  );
};

// Body Canvas Component
const BodyCanvas = (props: {
  bodyParts: BodyPart[];
  searchText: string;
  onSearch: (text: string) => void;
  onSelectPart: (zone: string) => void;
}) => {
  const { bodyParts, searchText, onSearch, onSelectPart } = props;

  const filteredParts = bodyParts.filter((part) =>
    part.name.toLowerCase().includes(searchText.toLowerCase()),
  );

  const availableParts = filteredParts.filter(
    (part) => !part.covered && part.current_tattoos < part.max_tattoos,
  );
  const unavailableParts = filteredParts.filter(
    (part) => part.covered || part.current_tattoos >= part.max_tattoos,
  );

  const EmptyState = ({
    icon,
    message,
    hint,
  }: {
    icon: string;
    message: string;
    hint?: string;
  }) => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        color: '#999',
        padding: '2rem',
        flex: 1,
      }}
    >
      <Icon name={icon} size={2} />
      <div style={{ marginTop: '0.5rem' }}>{message}</div>
      {hint && (
        <div style={{ fontSize: '0.8rem', marginTop: '0.5rem' }}>{hint}</div>
      )}
    </div>
  );

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        gap: '1rem',
      }}
    >
      <div style={{ flexShrink: 0 }}>
        <Input
          placeholder="Search body areas..."
          value={searchText}
          onChange={(e, value) => onSearch(value)}
          fluid
          icon="search"
        />
      </div>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: '1rem',
          flex: 1,
          minHeight: 0,
        }}
      >
        {/* Available Areas */}
        <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <Section
            title={`Available Canvas (${availableParts.length})`}
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              minHeight: 0,
            }}
            color="good"
          >
            {availableParts.length === 0 ? (
              <EmptyState
                icon="search"
                message="No available canvas areas"
                hint="Remove clothing or search different terms"
              />
            ) : (
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                  flex: 1,
                  overflowY: 'auto',
                }}
              >
                {availableParts.map((part) => (
                  <BodyPartCard
                    key={part.zone}
                    part={part}
                    status="available"
                    onSelect={onSelectPart}
                  />
                ))}
              </div>
            )}
          </Section>
        </div>

        {/* Unavailable Areas */}
        <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <Section
            title={`Unavailable (${unavailableParts.length})`}
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              minHeight: 0,
            }}
            color="average"
          >
            {unavailableParts.length === 0 ? (
              <EmptyState icon="check" message="All areas accessible" />
            ) : (
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                  flex: 1,
                  overflowY: 'auto',
                }}
              >
                {unavailableParts.map((part) => (
                  <BodyPartCard
                    key={part.zone}
                    part={part}
                    status={part.covered ? 'covered' : 'full'}
                    onSelect={onSelectPart}
                  />
                ))}
              </div>
            )}
          </Section>
        </div>
      </div>
    </div>
  );
};

// Body Part Card Component
const BodyPartCard = (props: {
  part: BodyPart;
  status: string;
  onSelect: (zone: string) => void;
}) => {
  const { part, status, onSelect } = props;
  const disabled = status !== 'available';

  const getStatusIcon = () => {
    switch (status) {
      case 'available':
        return 'user-circle';
      case 'covered':
        return 'tshirt';
      case 'full':
        return 'ban';
      default:
        return 'question';
    }
  };

  const getStatusText = () => {
    switch (status) {
      case 'available':
        return 'Ready';
      case 'covered':
        return 'Covered';
      case 'full':
        return 'Full';
      default:
        return 'Unknown';
    }
  };

  return (
    <Button
      fluid
      style={{ height: '60px', textAlign: 'left' }}
      color={status === 'available' ? 'good' : 'average'}
      disabled={disabled}
      tooltip={
        disabled
          ? status === 'covered'
            ? 'Covered by clothing'
            : 'Maximum tattoos reached'
          : `Select ${part.name} for tattooing`
      }
      onClick={() => !disabled && onSelect(part.zone)}
    >
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: 'auto 1fr auto',
          alignItems: 'center',
          gap: '0.5rem',
          height: '100%',
        }}
      >
        <div style={{ fontSize: '1.2rem' }}>
          <Icon name={getStatusIcon()} />
        </div>
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '0.2rem',
          }}
        >
          <div style={{ fontWeight: 'bold' }}>{part.name}</div>
          <div style={{ fontSize: '0.8rem', color: '#999' }}>
            {part.current_tattoos}/{part.max_tattoos} tattoos
          </div>
          <div style={{ fontSize: '0.7rem', fontWeight: 'bold' }}>
            {getStatusText()}
          </div>
        </div>
        {!disabled && (
          <div style={{ color: '#999' }}>
            <Icon name="chevron-right" />
          </div>
        )}
      </div>
    </Button>
  );
};

// Design Studio Component
const DesignStudio = (props: {
  artistName: string;
  design: string;
  selectedZone: string;
  bodyParts: BodyPart[];
  layer: number;
  font: string;
  flair: string | null;
  color: string;
  fontOptions: Record<string, string>;
  flairOptions: Record<string, string>;
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
    selectedZone,
    bodyParts,
    layer,
    font,
    flair,
    color,
    fontOptions,
    flairOptions,
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

  const currentZone = bodyParts.find((part) => part.zone === selectedZone);
  const isSignature = artistName.includes('%s');

  const EmptyPreview = ({
    icon,
    message,
    hint,
  }: {
    icon: string;
    message: string;
    hint?: string;
  }) => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        textAlign: 'center',
        color: '#999',
        padding: '2rem',
        height: '100%',
      }}
    >
      <Icon name={icon} size={3} />
      <div style={{ marginTop: '1rem', fontSize: '1.1rem' }}>{message}</div>
      {hint && (
        <div style={{ fontSize: '0.9rem', marginTop: '0.5rem' }}>{hint}</div>
      )}
    </div>
  );

  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        gap: '1rem',
      }}
    >
      {/* Studio Header */}
      <Section style={{ flexShrink: 0 }}>
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: 'auto 1fr auto',
            alignItems: 'center',
            gap: '1rem',
          }}
        >
          <Button onClick={onBack}>
            <Icon name="arrow-left" />
            Change Canvas
          </Button>
          <div
            style={{
              fontWeight: 'bold',
              fontSize: '1.1rem',
              textAlign: 'center',
            }}
          >
            Designing for {currentZone?.name || selectedZone}
          </div>
          <Button
            color="good"
            disabled={!canApply}
            onClick={onApply}
            tooltip={
              !canApply ? 'Complete all required fields' : 'Apply tattoo'
            }
          >
            <Icon name="paint-brush" />
            Apply Tattoo ({inkUses} left)
          </Button>
        </div>
      </Section>

      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1.5fr 1fr',
          gap: '1rem',
          flex: 1,
          minHeight: 0,
        }}
      >
        {/* Design Controls */}
        <div style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}>
          <Section
            title="Tattoo Design"
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              minHeight: 0,
            }}
            fill
          >
            <div
              style={{
                display: 'flex',
                flexDirection: 'column',
                gap: '1rem',
                flex: 1,
                overflowY: 'auto',
              }}
            >
              {/* Artist Name */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                }}
              >
                <div
                  style={{
                    fontWeight: 'bold',
                    color: '#ddd',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '0.5rem',
                  }}
                >
                  Artist Signature
                  {isSignature && (
                    <span
                      style={{
                        background: '#4d82ff',
                        color: 'white',
                        padding: '0.2rem 0.5rem',
                        borderRadius: '0.25rem',
                        fontSize: '0.8rem',
                        display: 'flex',
                        alignItems: 'center',
                        gap: '0.3rem',
                      }}
                    >
                      <Icon name="signature" />
                      Auto-signature
                    </span>
                  )}
                </div>
                <Input
                  value={artistName}
                  onChange={(e, value) => onArtistChange(value)}
                  placeholder="Enter artist name (use %s for automatic signature)"
                  fluid
                />
                {isSignature && (
                  <div style={{ fontSize: '0.8rem', color: '#999' }}>
                    %s will be replaced with your name during application
                  </div>
                )}
              </div>

              {/* Tattoo Design */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                }}
              >
                <div style={{ fontWeight: 'bold', color: '#ddd' }}>
                  Tattoo Artwork
                </div>
                <TextArea
                  value={design}
                  onChange={(e, value) => onDesignChange(value)}
                  placeholder="Describe your tattoo design in detail..."
                  height="100px"
                  fluid
                />
                <div style={{ fontSize: '0.8rem', color: '#999' }}>
                  Supports emojis like :heart: :star: :smile: and text
                  formatting
                </div>
              </div>

              {/* Style Options */}
              <div
                style={{
                  display: 'grid',
                  gridTemplateColumns: '1fr 1fr',
                  gap: '1rem',
                }}
              >
                <div
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '0.5rem',
                    flex: 1,
                  }}
                >
                  <div style={{ fontWeight: 'bold', color: '#ddd' }}>
                    Writing Instrument
                  </div>
                  <Dropdown
                    selected={font}
                    options={fontOptions}
                    onSelected={onFontChange}
                    width="100%"
                  />
                </div>
                <div
                  style={{
                    display: 'flex',
                    flexDirection: 'column',
                    gap: '0.5rem',
                    flex: 1,
                  }}
                >
                  <div style={{ fontWeight: 'bold', color: '#ddd' }}>
                    Text Flair
                  </div>
                  <Dropdown
                    selected={flair || 'null'}
                    options={flairOptions}
                    onSelected={(value) =>
                      onFlairChange(value === 'null' ? null : value)
                    }
                    width="100%"
                  />
                </div>
              </div>

              {/* Layer Selection */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                }}
              >
                <div style={{ fontWeight: 'bold', color: '#ddd' }}>
                  Layer Placement
                </div>
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: '1fr 1fr 1fr',
                    gap: '0.5rem',
                  }}
                >
                  {[1, 2, 3].map((layerNum) => {
                    const isTaken = existingTattoos.some(
                      (t) => t.layer === layerNum,
                    );
                    const isSelected = layer === layerNum;
                    const layerNames = [
                      'Under (Base)',
                      'Normal (Middle)',
                      'Over (Top)',
                    ];

                    return (
                      <Tooltip
                        key={layerNum}
                        content={
                          isTaken
                            ? `Layer occupied - will replace existing tattoo`
                            : `Place tattoo on ${layerNames[layerNum - 1]} layer`
                        }
                      >
                        <Button
                          fluid
                          style={{ height: '60px' }}
                          color={
                            isTaken ? 'yellow' : isSelected ? 'good' : 'default'
                          }
                          onClick={() => {
                            if (isTaken) {
                              if (
                                window.confirm(
                                  'This layer has an existing tattoo. Applying a new design will replace it. Continue?',
                                )
                              ) {
                                onLayerChange(layerNum);
                              }
                            } else {
                              onLayerChange(layerNum);
                            }
                          }}
                        >
                          <div
                            style={{
                              display: 'flex',
                              flexDirection: 'column',
                              alignItems: 'center',
                              gap: '0.3rem',
                            }}
                          >
                            <div
                              style={{ fontSize: '1.2rem', fontWeight: 'bold' }}
                            >
                              {layerNum}
                            </div>
                            <div
                              style={{
                                fontSize: '0.8rem',
                                textAlign: 'center',
                              }}
                            >
                              {layerNames[layerNum - 1]}
                            </div>
                            {isTaken && (
                              <div
                                style={{
                                  fontSize: '0.7rem',
                                  color: '#ffa500',
                                  fontWeight: 'bold',
                                }}
                              >
                                Occupied
                              </div>
                            )}
                          </div>
                        </Button>
                      </Tooltip>
                    );
                  })}
                </div>
              </div>

              {/* Color Selection */}
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                }}
              >
                <div style={{ fontWeight: 'bold', color: '#ddd' }}>
                  Ink Color
                </div>
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'auto 1fr auto',
                    alignItems: 'center',
                    gap: '0.5rem',
                  }}
                >
                  <ColorBox
                    color={color}
                    style={{
                      width: '30px',
                      height: '30px',
                      border: '1px solid #666',
                    }}
                  />
                  <Input
                    value={color}
                    onChange={(e, value) => onColorChange(value)}
                    placeholder="#000000"
                  />
                  <Button
                    icon="palette"
                    onClick={onColorPick}
                    tooltip="Open color picker"
                  >
                    Pick
                  </Button>
                </div>
              </div>
            </div>
          </Section>
        </div>

        {/* Preview Panel */}
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '1rem',
            minHeight: 0,
          }}
        >
          {/* Existing Tattoos */}
          <Section
            title={`Existing Artwork (${existingTattoos.length}/3)`}
            style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}
            buttons={
              <Box color={existingTattoos.length >= 3 ? 'bad' : 'good'}>
                {existingTattoos.length}/3 slots used
              </Box>
            }
          >
            {existingTattoos.length === 0 ? (
              <EmptyPreview
                icon="canvas"
                message="Blank Canvas"
                hint="No tattoos yet"
              />
            ) : (
              <div
                style={{
                  display: 'flex',
                  flexDirection: 'column',
                  gap: '0.5rem',
                }}
              >
                {existingTattoos.map((tattoo, index) => (
                  <div
                    key={index}
                    style={{
                      background: 'rgba(0, 0, 0, 0.3)',
                      borderLeft: `4px solid ${tattoo.color}`,
                      padding: '0.5rem',
                      borderRadius: '0.25rem',
                    }}
                  >
                    <div
                      style={{
                        color: tattoo.color,
                        fontWeight: 'bold',
                        marginBottom: '0.3rem',
                        fontFamily:
                          tattoo.font === 'CRAYON_FONT'
                            ? 'Comic Sans MS, cursive'
                            : 'inherit',
                      }}
                    >
                      "{tattoo.design}"
                    </div>
                    <div
                      style={{
                        display: 'flex',
                        justifyContent: 'space-between',
                        fontSize: '0.8rem',
                        color: '#999',
                      }}
                    >
                      <span>by {tattoo.artist}</span>
                      <span>Layer {tattoo.layer}</span>
                    </div>
                    {tattoo.flair && (
                      <div
                        style={{
                          fontSize: '0.7rem',
                          color: '#4d82ff',
                          marginTop: '0.2rem',
                        }}
                      >
                        Style: {flairOptions[tattoo.flair]}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            )}
          </Section>

          {/* Live Preview */}
          <Section
            fill
            title="Live Preview"
            style={{ display: 'flex', flexDirection: 'column', minHeight: 0 }}
          >
            <div
              style={{
                height: '100%',
                display: 'flex',
                flexDirection: 'column',
              }}
            >
              {artistName || design ? (
                <div
                  style={{
                    border: `2px solid ${color}`,
                    padding: '1rem',
                    background: 'rgba(0, 0, 0, 0.1)',
                    borderRadius: '0.5rem',
                    display: 'flex',
                    flexDirection: 'column',
                    height: '100%',
                  }}
                >
                  <div
                    style={{
                      color: color,
                      borderBottom: `1px solid ${color}`,
                      paddingBottom: '0.5rem',
                      fontWeight: 'bold',
                      textAlign: 'center',
                      fontSize: '1rem',
                    }}
                  >
                    {currentZone?.name || selectedZone}
                  </div>

                  <div
                    style={{
                      flex: 1,
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      minHeight: '80px',
                      padding: '1rem 0',
                    }}
                  >
                    <div
                      style={{
                        color: color,
                        fontWeight: 'bold',
                        fontSize: '1.1rem',
                        lineHeight: '1.4',
                        textAlign: 'center',
                        fontFamily:
                          font === 'CRAYON_FONT'
                            ? 'Comic Sans MS, cursive'
                            : font === 'FOUNTAIN_PEN_FONT'
                              ? 'Brush Script MT, cursive'
                              : 'inherit',
                      }}
                    >
                      "{design || 'Your design will appear here'}"
                    </div>
                  </div>

                  <div
                    style={{
                      color: color,
                      borderTop: `1px solid ${color}`,
                      paddingTop: '0.5rem',
                      fontSize: '0.9rem',
                      textAlign: 'right',
                    }}
                  >
                    —{' '}
                    {isSignature
                      ? '[Your Signature]'
                      : artistName || 'Unknown Artist'}
                  </div>

                  <div style={{ marginTop: '1rem' }}>
                    <LabeledList>
                      <LabeledList.Item label="Instrument">
                        {fontOptions[font]}
                      </LabeledList.Item>
                      <LabeledList.Item label="Layer">
                        Layer {layer}
                      </LabeledList.Item>
                      <LabeledList.Item label="Flair">
                        {flair && flair !== 'null'
                          ? flairOptions[flair]
                          : 'None'}
                      </LabeledList.Item>
                    </LabeledList>
                  </div>
                </div>
              ) : (
                <EmptyPreview
                  icon="eye-slash"
                  message="Design Preview"
                  hint="Enter design details to see live preview"
                />
              )}
            </div>
          </Section>
        </div>
      </div>
    </div>
  );
};
