import {
  Box,
  Button,
  Input,
  LabeledList,
  Section,
  Stack,
  TextArea,
} from 'tgui-core/components';
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
    current_step,
    selected_zone_name,
    selected_layer,
  } = data;

  if (current_step === 'design_tattoo') {
    return <DesignTattooStep />;
  }

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
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
              <Box
                inline
                ml={1}
                style={{
                  display: 'inline-block',
                  width: '20px',
                  height: '20px',
                  backgroundColor: ink_color,
                  border: '1px solid #000',
                }}
              />
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section title="Available Body Parts">
          {body_parts.length === 0 && (
            <Box color="bad" textAlign="center">
              {ink_uses <= 0
                ? 'Out of ink! Use a toner cartridge to refill.'
                : 'No available body parts found! Target may be fully clothed or have no valid body parts.'}
            </Box>
          )}
          <Stack vertical>
            {body_parts.map((part) => (
              <Stack.Item key={part.zone}>
                <Button
                  fluid
                  disabled={
                    part.covered ||
                    part.current_tattoos >= part.max_tattoos ||
                    ink_uses <= 0
                  }
                  onClick={() => act('select_bodypart', { zone: part.zone })}
                  tooltip={
                    part.covered
                      ? 'Body part is covered by clothing - expose it first!'
                      : part.current_tattoos >= part.max_tattoos
                        ? `Maximum tattoos reached for this part (${part.max_tattoos})`
                        : ink_uses <= 0
                          ? 'Out of ink - refill the kit first!'
                          : `Apply tattoo to ${part.name}`
                  }
                  color={part.covered ? 'bad' : 'default'}
                >
                  <Stack>
                    <Stack.Item grow>
                      {part.name} ({part.current_tattoos}/{part.max_tattoos})
                    </Stack.Item>
                    <Stack.Item>
                      {part.covered ? '🔒 Covered' : '🔓 Exposed'}
                    </Stack.Item>
                  </Stack>
                </Button>
              </Stack.Item>
            ))}
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};

const DesignTattooStep = (props) => {
  const { act, data } = useBackend();
  const {
    ink_color,
    selected_zone_name,
    selected_layer,
  } = data;

  // Local state for form inputs - simple and direct
  let artistName = '';
  let tattooDesign = '';

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
        <Section
          title={`Design Tattoo for ${selected_zone_name}`}
          buttons={
            <Button icon="arrow-left" onClick={() => act('back_to_selection')}>
              Back
            </Button>
          }
        >
          <LabeledList>
            <LabeledList.Item label="Artist Name">
              <Input
                fluid
                placeholder="Enter your name or signature..."
                onChange={(e, value) => artistName = value}
                maxLength={50}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Tattoo Design">
              <TextArea
                fluid
                height="150px"
                placeholder="Describe the tattoo design in detail. Be creative!"
                onChange={(e, value) => tattooDesign = value}
                maxLength={500}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Button
                icon="palette"
                onClick={() => act('change_ink_color')}
                tooltip="Change ink color"
              />
              <Box
                inline
                ml={1}
                style={{
                  display: 'inline-block',
                  width: '24px',
                  height: '24px',
                  backgroundColor: ink_color,
                  border: '2px solid #000',
                  borderRadius: '3px',
                }}
              />
              <Box inline ml={1} color="label">
                {ink_color}
              </Box>
            </LabeledList.Item>
            <LabeledList.Item label="Layer">
              <Stack>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 1}
                    onClick={() => act('set_layer', { layer: 1 })}
                    tooltip="Under layer - appears behind other tattoos"
                  >
                    Under
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 2}
                    onClick={() => act('set_layer', { layer: 2 })}
                    tooltip="Normal layer - standard placement"
                  >
                    Normal
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    selected={selected_layer === 3}
                    onClick={() => act('set_layer', { layer: 3 })}
                    tooltip="Over layer - appears in front of other tattoos"
                  >
                    Over
                  </Button>
                </Stack.Item>
              </Stack>
            </LabeledList.Item>
            <LabeledList.Item>
              <Button
                fluid
                icon="check"
                color="good"
                onClick={() => act('apply_tattoo', {
                  artist_name: artistName,
                  tattoo_design: tattooDesign,
                })}
                tooltip="Apply the tattoo to the selected body part"
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
