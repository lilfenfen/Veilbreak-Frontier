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
              <Flex align="center">
                <Flex.Item>
                  <Button
                    icon="palette"
                    content="Change Color"
                    onClick={() => act('change_ink_color')}
                  />
                </Flex.Item>
                <Flex.Item ml={1}>
                  <Box
                    style={{
                      display: 'inline-block',
                      width: '24px',
                      height: '24px',
                      backgroundColor: ink_color,
                      border: '2px solid #000',
                      borderRadius: '2px',
                    }}
                  />
                </Flex.Item>
                <Flex.Item ml={1}>{ink_color}</Flex.Item>
              </Flex>
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
                  <Flex align="center" justify="space-between">
                    <Flex.Item>{part.name}</Flex.Item>
                    <Flex.Item>
                      ({part.current_tattoos}/{part.max_tattoos})
                    </Flex.Item>
                    <Flex.Item>{part.covered ? '🔒' : '🔓'}</Flex.Item>
                  </Flex>
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

  // Debug logging to see what values we're getting
  console.log('Tattoo data:', { tattoo_name, tattoo_desc, selected_layer });

  // Simple check - if both fields have any content
  const canApply =
    tattoo_name &&
    tattoo_name.length > 0 &&
    tattoo_desc &&
    tattoo_desc.length > 0;

  const handleNameChange = (value) => {
    console.log('Name changed to:', value);
    act('update_tattoo_name', { name: value });
  };

  const handleDescChange = (value) => {
    console.log('Desc changed to:', value);
    act('update_tattoo_desc', { desc: value });
  };

  const handleLayerChange = (layer) => {
    act('update_tattoo_layer', { layer: layer });
  };

  const handleApply = () => {
    if (canApply) {
      act('apply_tattoo', {
        name: tattoo_name,
        desc: tattoo_desc,
        layer: selected_layer,
      });
    }
  };

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
          <Stack vertical fill>
            <Stack.Item>
              <LabeledList>
                <LabeledList.Item label="Tattoo Name">
                  <Input
                    fluid
                    value={tattoo_name}
                    placeholder="Enter tattoo name..."
                    onChange={(e, value) => handleNameChange(value)}
                  />
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>

            <Stack.Item grow>
              <LabeledList>
                <LabeledList.Item label="Description">
                  <TextArea
                    fluid
                    value={tattoo_desc}
                    height="100%"
                    placeholder="Enter tattoo description..."
                    onChange={(e, value) => handleDescChange(value)}
                  />
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>

            <Stack.Item>
              <LabeledList>
                <LabeledList.Item label="Current Values">
                  <Box>
                    Name: "{tattoo_name}" ({tattoo_name?.length || 0} chars)
                    <br />
                    Desc: "{tattoo_desc}" ({tattoo_desc?.length || 0} chars)
                    <br />
                    Can Apply: {canApply ? 'YES' : 'NO'}
                  </Box>
                </LabeledList.Item>

                <LabeledList.Item label="Ink Color">
                  <Flex align="center">
                    <Flex.Item>
                      <Button
                        icon="palette"
                        onClick={() => act('change_ink_color')}
                      />
                    </Flex.Item>
                    <Flex.Item ml={1}>
                      <Box
                        style={{
                          display: 'inline-block',
                          width: '24px',
                          height: '24px',
                          backgroundColor: ink_color,
                          border: '2px solid #000',
                          borderRadius: '2px',
                        }}
                      />
                    </Flex.Item>
                    <Flex.Item ml={1}>{ink_color}</Flex.Item>
                  </Flex>
                </LabeledList.Item>

                <LabeledList.Item label="Layer">
                  <Flex>
                    <Flex.Item>
                      <Button
                        selected={selected_layer === 1}
                        onClick={() => handleLayerChange(1)}
                      >
                        Under Layer
                      </Button>
                    </Flex.Item>
                    <Flex.Item ml={1}>
                      <Button
                        selected={selected_layer === 2}
                        onClick={() => handleLayerChange(2)}
                      >
                        Normal Layer
                      </Button>
                    </Flex.Item>
                    <Flex.Item ml={1}>
                      <Button
                        selected={selected_layer === 3}
                        onClick={() => handleLayerChange(3)}
                      >
                        Over Layer
                      </Button>
                    </Flex.Item>
                  </Flex>
                </LabeledList.Item>

                <LabeledList.Item>
                  <Button
                    fluid
                    icon="check"
                    color={canApply ? 'good' : 'default'}
                    disabled={!canApply}
                    onClick={handleApply}
                  >
                    {canApply ? 'Apply Tattoo' : 'Fill Name and Description'}
                  </Button>
                </LabeledList.Item>
              </LabeledList>
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
