import { Box, Button, LabeledList, Section } from 'tgui-core/components';

import { useBackend } from '../backend';
import { Window } from '../layouts';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_uses,
    ink_color,
    body_parts,
    selected_zone,
    current_step,
  } = data;

  if (current_step === 'design_tattoo') {
    return <DesignTattooStep />;
  }

  return (
    <Window width={400} height={500}>
      <Window.Content>
        <Section title={`Tattooing: ${target_name}`}>
          <LabeledList>
            <LabeledList.Item label="Ink Remaining">
              <Box color={ink_uses > 0 ? 'good' : 'bad'}>
                {ink_uses}/{max_uses} uses
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Button
                icon="palette"
                content="Change Color"
                onClick={() => act('change_ink_color')}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Current Color">
              <Box
                style={{
                  display: 'inline-block',
                  width: '20px',
                  height: '20px',
                  backgroundColor: ink_color,
                  border: '1px solid #000',
                  marginRight: '5px',
                }}
              />
              {ink_color}
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Available Body Parts" scrollable fill>
          {body_parts.length === 0 && (
            <Box color="bad" textAlign="center">
              No available body parts found!
            </Box>
          )}
          {body_parts.map((part) => (
            <Button
              key={part.zone}
              fluid
              disabled={
                part.covered ||
                part.current_tattoos >= part.max_tattoos ||
                ink_uses <= 0
              }
              onClick={() => act('select_bodypart', { zone: part.zone })}
              tooltip={
                part.covered
                  ? 'Body part is covered by clothing'
                  : part.current_tattoos >= part.max_tattoos
                    ? 'Maximum tattoos reached for this part'
                    : ink_uses <= 0
                      ? 'Out of ink'
                      : `Apply tattoo to ${part.name}`
              }
            >
              <Box inline>
                {part.name} ({part.current_tattoos}/{part.max_tattoos})
                {part.covered ? ' 🔒' : ' 🔓'}
              </Box>
            </Button>
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};

const DesignTattooStep = (props) => {
  const { act, data } = useBackend();
  const { target_name, ink_color, selected_zone } = data;

  const [tattooName, setTattooName] = useLocalState(context, 'tattooName', '');
  const [tattooDesc, setTattooDesc] = useLocalState(context, 'tattooDesc', '');
  const [selectedLayer, setSelectedLayer] = useLocalState(
    context,
    'selectedLayer',
    2,
  );

  return (
    <Window width={400} height={400}>
      <Window.Content>
        <Section
          title={`Design Tattoo for ${selected_zone}`}
          buttons={
            <Button icon="arrow-left" onClick={() => act('back_to_selection')}>
              Back
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Tattoo Name">
              <input
                type="text"
                value={tattooName}
                style={{ width: '100%' }}
                onChange={(e) => setTattooName(e.target.value)}
                placeholder="Enter tattoo name..."
              />
            </LabeledList.Item>
            <LabeledList.Item label="Description">
              <textarea
                value={tattooDesc}
                style={{
                  width: '100%',
                  height: '80px',
                  resize: 'vertical',
                }}
                onChange={(e) => setTattooDesc(e.target.value)}
                placeholder="Enter tattoo description..."
              />
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Box inline>
                <Box
                  style={{
                    display: 'inline-block',
                    width: '20px',
                    height: '20px',
                    backgroundColor: ink_color,
                    border: '1px solid #000',
                    marginRight: '5px',
                  }}
                />
                {ink_color}
              </Box>
              <Button
                ml={1}
                icon="palette"
                onClick={() => act('change_ink_color')}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Layer">
              <Button
                selected={selectedLayer === 1}
                onClick={() => setSelectedLayer(1)}
              >
                Under
              </Button>
              <Button
                selected={selectedLayer === 2}
                onClick={() => setSelectedLayer(2)}
              >
                Normal
              </Button>
              <Button
                selected={selectedLayer === 3}
                onClick={() => setSelectedLayer(3)}
              >
                Over
              </Button>
            </LabeledList.Item>
            <LabeledList.Item>
              <Button
                fluid
                icon="check"
                color="good"
                disabled={!tattooName || !tattooDesc}
                onClick={() =>
                  act('apply_tattoo', {
                    name: tattooName,
                    desc: tattooDesc,
                    layer: selectedLayer,
                  })
                }
              >
                Apply Tattoo
              </Button>
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
