import { useBackend } from '../backend';
import { Box, Button, ColorBox, Input, LabeledList, ProgressBar, Section, Stack, Tabs } from 'tgui-core/components';
import { Window } from '../layouts';

export const TattooKit = (props) => {
  const { act, data } = useBackend();
  const {
    target_name,
    ink_uses,
    max_ink_uses,
    ink_color,
    expanded_parts,
    artist_names,
    tattoo_designs,
    selected_layers,
    selected_fonts,
    body_parts = [],
  } = data;

  return (
    <Window
      title="Professional Tattoo Kit"
      width={800}
      height={600}>
      <Window.Content scrollable>
        <Section
          title={`Target: ${target_name}`}
          buttons={
            <Stack>
              <Stack.Item>
                <ColorBox color={ink_color} />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="palette"
                  tooltip="Change Ink Color"
                  onClick={() => act('change_color')}
                />
              </Stack.Item>
              <Stack.Item>
                <Button
                  icon="fill-drip"
                  tooltip="Refill Ink"
                  onClick={() => act('refill_ink')}
                />
              </Stack.Item>
            </Stack>
          }>
          <LabeledList>
            <LabeledList.Item label="Ink Remaining">
              <ProgressBar
                value={ink_uses}
                minValue={0}
                maxValue={max_ink_uses}
                color={ink_uses > 0 ? 'good' : 'bad'}>
                {ink_uses}/{max_ink_uses}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>

        <Section title="Body Parts">
          {body_parts.length === 0 ? (
            <Box color="bad">No accessible body parts found!</Box>
          ) : (
            body_parts.map((part) => (
              <BodyPartSection
                key={part.zone}
                part={part}
                expanded={expanded_parts.includes(part.zone)}
                artist_name={artist_names[part.zone]}
                tattoo_design={tattoo_designs[part.zone]}
                selected_layer={selected_layers[part.zone]}
                selected_font={selected_fonts[part.zone]}
                act={act}
              />
            ))
          )}
        </Section>
      </Window.Content>
    </Window>
  );
};

const BodyPartSection = (props) => {
  const {
    part,
    expanded,
    artist_name,
    tattoo_design,
    selected_layer,
    selected_font,
    act,
  } = props;

  return (
    <Section
      title={
        <Box inline>
          {part.name}
          {part.covered && (
            <Box inline color="bad" ml={1}>
              (Covered)
            </Box>
          )}
          <Box inline color="label" ml={1}>
            ({part.current_tattoos}/{part.max_tattoos} tattoos)
          </Box>
        </Box>
      }
      buttons={
        <Button
          icon={expanded ? 'chevron-up' : 'chevron-down'}
          color="transparent"
          onClick={() => act('toggle_expand', { zone: part.zone })}
        />
      }>
      {!expanded ? (
        <Box color="label">
          <div dangerouslySetInnerHTML={{ __html: part.preview_text }} />
        </Box>
      ) : (
        <Stack vertical>
          <Stack.Item>
            <Box color="label" mb={1}>
              <div dangerouslySetInnerHTML={{ __html: part.preview_text }} />
            </Box>
          </Stack.Item>

          <Stack.Item>
            <LabeledList>
              <LabeledList.Item label="Artist Name">
                <Input
                  fluid
                  value={artist_name || ''}
                  placeholder="Enter artist name..."
                  onChange={(e, value) =>
                    act('set_artist', {
                      zone: part.zone,
                      value: value,
                    })
                  }
                />
              </LabeledList.Item>

              <LabeledList.Item label="Tattoo Design">
                <Input
                  fluid
                  value={tattoo_design || ''}
                  placeholder="Describe the tattoo design..."
                  onChange={(e, value) =>
                    act('set_design', {
                      zone: part.zone,
                      value: value,
                    })
                  }
                />
              </LabeledList.Item>

              <LabeledList.Item label="Layer">
                <Stack>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 1}
                      onClick={() =>
                        act('set_layer', {
                          zone: part.zone,
                          layer: 1,
                        })
                      }>
                      Under
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 2}
                      onClick={() =>
                        act('set_layer', {
                          zone: part.zone,
                          layer: 2,
                        })
                      }>
                      Normal
                    </Button>
                  </Stack.Item>
                  <Stack.Item>
                    <Button
                      selected={selected_layer === 3}
                      onClick={() =>
                        act('set_layer', {
                          zone: part.zone,
                          layer: 3,
                        })
                      }>
                      Over
                    </Button>
                  </Stack.Item>
                </Stack>
              </LabeledList.Item>

              <LabeledList.Item label="Font">
                <Tabs>
                  <Tabs.Tab
                    selected={selected_font === 'Pen'}
                    onClick={() =>
                      act('set_font', {
                        zone: part.zone,
                        font: 'Pen',
                      })
                    }>
                    Pen
                  </Tabs.Tab>
                  <Tabs.Tab
                    selected={selected_font === 'Fountain Pen'}
                    onClick={() =>
                      act('set_font', {
                        zone: part.zone,
                        font: 'Fountain Pen',
                      })
                    }>
                    Fountain Pen
                  </Tabs.Tab>
                  <Tabs.Tab
                    selected={selected_font === 'Crayon'}
                    onClick={() =>
                      act('set_font', {
                        zone: part.zone,
                        font: 'Crayon',
                      })
                    }>
                    Crayon
                  </Tabs.Tab>
                  <Tabs.Tab
                    selected={selected_font === 'Printer'}
                    onClick={() =>
                      act('set_font', {
                        zone: part.zone,
                        font: 'Printer',
                      })
                    }>
                    Printer
                  </Tabs.Tab>
                  <Tabs.Tab
                    selected={selected_font === 'Charcoal'}
                    onClick={() =>
                      act('set_font', {
                        zone: part.zone,
                        font: 'Charcoal',
                      })
                    }>
                    Charcoal
                  </Tabs.Tab>
                </Tabs>
              </LabeledList.Item>
            </LabeledList>
          </Stack.Item>

          <Stack.Item mt={1}>
            <Button
              fluid
              icon="paint-brush"
              color="good"
              disabled={part.covered || part.current_tattoos >= part.max_tattoos || ink_uses <= 0}
              tooltip={
                part.covered
                  ? 'Body part is covered!'
                  : part.current_tattoos >= part.max_tattoos
                    ? 'Maximum tattoos reached!'
                    : ink_uses <= 0
                      ? 'Out of ink!'
                      : 'Apply tattoo'
              }
              onClick={() => act('apply_tattoo', { zone: part.zone })}>
              Apply Tattoo
            </Button>
          </Stack.Item>
        </Stack>
      )}
    </Section>
  );
};
