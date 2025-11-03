import {
  Box,
  Button,
  Flex,
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
    selected_zone,
    current_step,
    tattoo_name = '',
    tattoo_desc = '',
    selected_layer = 2,
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
        <Section title="Available Body Parts" fill>
          {body_parts.length === 0 && (
            <Box color="bad" textAlign="center">
              No available body parts found!
            </Box>
          )}
          <Stack vertical fill>
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
                      ? 'Body part is covered by clothing'
                      : part.current_tattoos >= part.max_tattoos
                        ? 'Maximum tattoos reached for this part'
                        : ink_uses <= 0
                          ? 'Out of ink'
                          : `Apply tattoo to ${part.name}`
                  }
                >
                  {part.name} ({part.current_tattoos}/{part.max_tattoos})
                  {part.covered ? ' 🔒' : ' 🔓'}
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
    target_name,
    ink_color,
    selected_zone,
    tattoo_name = '',
    tattoo_desc = '',
    selected_layer = 2,
  } = data;

  const canApply =
    tattoo_name &&
    tattoo_name.length > 0 &&
    tattoo_desc &&
    tattoo_desc.length > 0;

  return (
    <Window width={500} height={600}>
      <Window.Content scrollable>
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
              <Input
                fluid
                value={tattoo_name}
                placeholder="Enter tattoo name..."
                onChange={(value) => act('update_tattoo_name', { name: value })}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Description">
              <TextArea
                fluid
                value={tattoo_desc}
                height="80px"
                placeholder="Enter tattoo description..."
                onChange={(value) => act('update_tattoo_desc', { desc: value })}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Ink Color">
              <Button icon="palette" onClick={() => act('change_ink_color')} />
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
            <LabeledList.Item label="Layer">
              <Button
                selected={selected_layer === 1}
                onClick={() => act('update_tattoo_layer', { layer: 1 })}
              >
                Under
              </Button>
              <Button
                selected={selected_layer === 2}
                onClick={() => act('update_tattoo_layer', { layer: 2 })}
              >
                Normal
              </Button>
              <Button
                selected={selected_layer === 3}
                onClick={() => act('update_tattoo_layer', { layer: 3 })}
              >
                Over
              </Button>
            </LabeledList.Item>
            <LabeledList.Item>
              <Button
                fluid
                icon="check"
                color={canApply ? 'good' : 'default'}
                disabled={!canApply}
                onClick={() =>
                  act('apply_tattoo', {
                    name: tattoo_name,
                    desc: tattoo_desc,
                    layer: selected_layer,
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
