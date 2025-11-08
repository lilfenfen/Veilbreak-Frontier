import { useBackend } from '../backend';
import { Box, Button, Dropdown, Input, LabeledList, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';
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

// Font options matching the DM defines
const FONT_OPTIONS = {
  'Verdana': 'Regular Pen',
  'Segoe Script': 'Fountain Pen',
  'Comic Sans MS': 'Crayon',
  'Times New Roman': 'Printer',
  'Candara': 'Charcoal',
};

export const TattooKit = (props) => {
  const { act, data } = useBackend<TattooKitData>();
  const {
    target_name,
    ink_uses,
    max_uses,
    ink_color,
    selected_zone,
    selected_zone_name,
    current_step,
    selected_layer,
    selected_font,
    artist_name,
    tattoo_design,
    body_parts = [],
    preview_text,
  } = data;

  // Calculate if we can apply based on current data state
  const canApply = artist_name?.trim() && tattoo_design?.trim();

  return (
    <Window
      width={720}
      height={800}
      theme="grey"
      resizable
    >
      <Window.Content scrollable>
        <Section title="Tattoo Kit">
          <LabeledList>
            <LabeledList.Item label="Target">
              {target_name || 'No Target'}
            </LabeledList.Item>
            <LabeledList.Item label="Ink Remaining">
              <ProgressBar
                value={ink_uses}
                minValue={0}
                maxValue={max_uses}
                color={ink_uses > 0 ? 'good' : 'bad'}>
                {ink_uses}/{max_uses}
              </ProgressBar>
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Box
                inline
                width="64px"
                height="64px"
                backgroundColor={ink_color}
                style={{
                  'border': '2px solid #555',
                  'border-radius': '4px',
                }}
              />
              <Button
                ml={1}
                icon="palette"
                onClick={() => act('change_ink_color')}>
                Change Color
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>

        {current_step === 'select_part' && (
          <BodyPartSelection
            bodyParts={body_parts}
            onSelect={(zone) => act('select_bodypart', { zone })}
          />
        )}

        {current_step === 'design_tattoo' && (
          <TattooDesign
            selectedZone={selected_zone_name}
            artistName={artist_name}
            tattooDesign={tattoo_design}
            selectedLayer={selected_layer}
            selectedFont={selected_font}
            previewText={preview_text}
            canApply={canApply}
            onBack={() => act('back_to_selection')}
            onApply={() => act('apply_tattoo')}
            onSetArtist={(value) => act('set_artist_name', { value })}
            onSetDesign={(value) => act('set_tattoo_design', { value })}
            onSetLayer={(layer) => act('set_layer', { layer })}
            onSetFont={(font) => act('set_font', { font })}
          />
        )}
      </Window.Content>
    </Window>
  );
};

const BodyPartSelection = (props: {
  bodyParts: BodyPart[];
  onSelect: (zone: string) => void;
}) => {
  const { bodyParts, onSelect } = props;

  return (
    <Section title="Select Body Part">
      <Stack vertical fill>
        {bodyParts.map((part) => (
          <Stack.Item key={part.zone}>
            <Button
              fluid
              icon={part.covered ? 'eye-slash' : 'eye'}
              color={part.covered ? 'bad' : part.current_tattoos >= part.max_tattoos ? 'average' : 'default'}
              disabled={part.covered || part.current_tattoos >= part.max_tattoos}
              onClick={() => onSelect(part.zone)}
              tooltip={
                part.covered
                  ? 'This body part is covered by clothing'
                  : part.current_tattoos >= part.max_tattoos
                    ? 'Maximum tattoos reached for this body part'
                    : `Current tattoos: ${part.current_tattoos}/${part.max_tattoos}`
              }
              style={{
                'margin-bottom': '2px',
              }}
            >
              {part.name} ({part.current_tattoos}/{part.max_tattoos})
            </Button>
          </Stack.Item>
        ))}
      </Stack>
    </Section>
  );
};

const TattooDesign = (props: {
  selectedZone: string;
  artistName: string;
  tattooDesign: string;
  selectedLayer: number;
  selectedFont: string;
  previewText: string;
  canApply: boolean;
  onBack: () => void;
  onApply: () => void;
  onSetArtist: (value: string) => void;
  onSetDesign: (value: string) => void;
  onSetLayer: (layer: number) => void;
  onSetFont: (font: string) => void;
}) => {
  const {
    selectedZone,
    artistName,
    tattooDesign,
    selectedLayer,
    selectedFont,
    previewText,
    canApply,
    onBack,
    onApply,
    onSetArtist,
    onSetDesign,
    onSetLayer,
    onSetFont,
  } = props;

  const layerOptions = [
    { value: 1, label: 'Under Layer', tooltip: 'Appears under skin details' },
    { value: 2, label: 'Normal Layer', tooltip: 'Standard tattoo layer' },
    { value: 3, label: 'Over Layer', tooltip: 'Appears over skin details' },
  ];

  return (
    <Section
      title={`Design Tattoo for ${selectedZone}`}
      buttons={
        <Button icon="arrow-left" onClick={onBack}>
          Back to Selection
        </Button>
      }
    >
      <Stack vertical fill>
        {/* Configuration Section */}
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Section title="Artist Information">
                <LabeledList>
                  <LabeledList.Item label="Artist Name">
                    <Input
                      fluid
                      value={artistName || ''}
                      placeholder="Enter artist name or use %s for your signature..."
                      onChange={(e, value) => onSetArtist(value)}
                      maxLength={50}
                    />
                  </LabeledList.Item>
                  <LabeledList.Item label="Tattoo Font">
                    <Dropdown
                      width="100%"
                      selected={FONT_OPTIONS[selectedFont] || selectedFont}
                      options={Object.values(FONT_OPTIONS)}
                      onSelected={(value) => {
                        const fontKey = Object.keys(FONT_OPTIONS).find(
                          key => FONT_OPTIONS[key] === value
                        );
                        onSetFont(fontKey || 'Verdana');
                      }}
                    />
                  </LabeledList.Item>
                </LabeledList>
                <Box fontSize="0.8rem" color="label" mt={1}>
                  <div><strong>Placeholders:</strong></div>
                  <div>%s or %sign - Your signature</div>
                  <div>%d or %date - Current date</div>
                  <div>%t or %time - Current time</div>
                </Box>
              </Section>
            </Stack.Item>
            <Stack.Item>
              <Section title="Tattoo Layer">
                <Tabs vertical>
                  {layerOptions.map((layer) => (
                    <Tabs.Tab
                      key={layer.value}
                      selected={selectedLayer === layer.value}
                      icon="layer-group"
                      tooltip={layer.tooltip}
                      onClick={() => onSetLayer(layer.value)}
                    >
                      {layer.label}
                    </Tabs.Tab>
                  ))}
                </Tabs>
              </Section>
            </Stack.Item>
          </Stack>
        </Stack.Item>

        {/* Tattoo Design Input */}
        <Stack.Item>
          <Section title="Tattoo Design Description">
            <Input
              textArea
              fluid
              height="120px"
              value={tattooDesign || ''}
              placeholder="Describe the tattoo design in detail. Be creative! You can include symbols, patterns, text, emojis, or any other elements you want in your tattoo. Maximum 500 characters."
              onChange={(e, value) => onSetDesign(value)}
              maxLength={500}
            />
            <Box mt={1} textAlign="right">
              Characters: {(tattooDesign || '').length}/500
            </Box>
          </Section>
        </Stack.Item>

        {/* Preview Section */}
        <Stack.Item>
          <Section title="Preview (Shows all tattoos on this body part)">
            <Box
              style={{
                'border': '2px solid #555',
                'padding': '0.75rem',
                'background': 'rgba(80,80,80,0.9)', // Dark grey background
                'min-height': '120px',
                'border-radius': '4px',
              }}
            >
              <Box
                style={{
                  'color': '#ffffff', // White text for contrast
                  'min-height': '100px',
                }}
                dangerouslySetInnerHTML={{
                  __html: previewText || '<span style="color: #cccccc;">Enter tattoo details to see preview...</span>',
                }}
              />
            </Box>
            <Box mt={1} fontSize="0.8rem" color="label">
              This preview shows how all tattoos on this body part will appear when examined, including layer ordering.
            </Box>
          </Section>
        </Stack.Item>

        {/* Apply Button */}
        <Stack.Item>
          <Button
            fluid
            icon="check"
            color={canApply ? "good" : "bad"}
            fontSize="16px"
            py={1}
            disabled={!canApply}
            onClick={onApply}
            tooltip={
              !canApply
                ? 'Please fill in both artist name and tattoo design'
                : `Apply tattoo to ${selectedZone}`
            }
            style={{
              'margin-top': '4px',
            }}
          >
            {canApply
              ? `APPLY TATTOO TO ${selectedZone.toUpperCase()}`
              : 'FILL IN ARTIST NAME AND DESIGN'
            }
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
