import { useState } from 'react';
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
        <Section title="Available Body Parts" scrollable fill>
          {body_parts.length === 0 && (
            <Box color="bad" textAlign="center">
              No available body parts found!
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
  const { target_name, ink_color, selected_zone } = data;

  const [tattooName, setTattooName] = useState('');
  const [tattooDesc, setTattooDesc] = useState('');
  const [selectedLayer, setSelectedLayer] = useState(2);

  const handleApply = () => {
    if (tattooName && tattooDesc) {
      act('apply_tattoo', {
        name: tattooName,
        desc: tattooDesc,
        layer: selectedLayer,
      });
    }
  };

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
              <Input
                value={tattooName}
                width="100%"
                placeholder="Enter tattoo name..."
                onChange={(e, value) => setTattooName(value)}
              />
            </LabeledList.Item>
            <LabeledList.Item label="Description">
              <TextArea
                value={tattooDesc}
                height="80px"
                placeholder="Enter tattoo description..."
                onChange={(e, value) => setTattooDesc(value)}
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
                onClick={handleApply}
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
