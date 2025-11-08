import { useBackend } from '../backend';
import { Box, Button, Input, LabeledList, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';
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
  artist_name: string;
  tattoo_design: string;
  body_parts: BodyPart[];
};

type BodyPart = {
  zone: string;
  name: string;
  covered: boolean;
  current_tattoos: number;
  max_tattoos: number;
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
    artist_name,
    tattoo_design,
    body_parts = [],
  } = data;

  return (
    <Window width={500} height={600} theme="neutral">
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
              <Box inline width="64px" height="64px" backgroundColor={ink_color} />
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
            onBack={() => act('back_to_selection')}
            onApply={(artist, design, layer) =>
              act('apply_tattoo', {
                artist: artist,
                design: design,
                layer: layer,
              })
            }
            onSetArtist={(name) => act('set_artist_name', { value: name })}
            onSetDesign={(design) => act('set_tattoo_design', { value: design })}
            onSetLayer={(layer) => act('set_layer', { layer: layer })}
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
              }>
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
  onBack: () => void;
  onApply: (artist: string, design: string, layer: number) => void;
  onSetArtist: (name: string) => void;
  onSetDesign: (design: string) => void;
  onSetLayer: (layer: number) => void;
}) => {
  const {
    selectedZone,
    artistName,
    tattooDesign,
    selectedLayer,
    onBack,
    onApply,
    onSetArtist,
    onSetDesign,
    onSetLayer,
  } = props;

  const layerOptions = [
    { value: 1, label: 'Under Layer', tooltip: 'Appears under skin details' },
    { value: 2, label: 'Normal Layer', tooltip: 'Standard tattoo layer' },
    { value: 3, label: 'Over Layer', tooltip: 'Appears over skin details' },
  ];

  return (
    <Section
      title={`Design Tattoo - ${selectedZone}`}
      buttons={<Button icon="arrow-left" onClick={onBack}>Back</Button>}>
      <Stack vertical fill>
        <Stack.Item>
          <LabeledList>
            <LabeledList.Item label="Artist Name">
              <Input
                fluid
                value={artistName}
                placeholder="Enter artist name..."
                onChange={(e, value) => onSetArtist(value)}
                maxLength={50}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Tattoo Layer">
              <Tabs fluid>
                {layerOptions.map((layer) => (
                  <Tabs.Tab
                    key={layer.value}
                    selected={selectedLayer === layer.value}
                    icon="layer-group"
                    tooltip={layer.tooltip}
                    onClick={() => onSetLayer(layer.value)}>
                    {layer.label}
                  </Tabs.Tab>
                ))}
              </Tabs>
            </LabeledList.Item>
          </LabeledList>
        </Stack.Item>

        <Stack.Item grow>
          <Section title="Tattoo Design" fill scrollable>
            <Input
              textArea
              fluid
              height="100px"
              value={tattooDesign}
              placeholder="Describe the tattoo design in detail..."
              onChange={(e, value) => onSetDesign(value)}
              maxLength={500}
            />
          </Section>
        </Stack.Item>

        <Stack.Item>
          <Button
            fluid
            icon="check"
            color="good"
            disabled={!artistName.trim() || !tattooDesign.trim()}
            onClick={() => onApply(artistName, tattooDesign, selectedLayer)}
            tooltip={
              !artistName.trim() || !tattooDesign.trim()
                ? 'Please fill in both artist name and tattoo design'
                : 'Apply tattoo'
            }>
            Apply Tattoo
          </Button>
        </Stack.Item>
      </Stack>
    </Section>
  );
};
