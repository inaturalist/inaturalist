import React from "react";
import type { Meta, StoryObj } from "@storybook/react";
import Carousel from "./carousel";
import type { CarouselProps } from "./carousel";

const meta: Meta<typeof Carousel> = {
  title: "Shared/Carousel",
  component: Carousel
};

export default meta;
type Story = StoryObj<typeof Carousel>;

const PlaceholderItem = ( { label }: { label: string } ) => (
  <div
    style={{
      width: 100,
      height: 100,
      background: "#e8f5e9",
      border: "1px solid #74ac00",
      borderRadius: 4,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      fontSize: 12,
      color: "#444"
    }}
  >
    { label }
  </div>
);

type DemoProps = Omit<CarouselProps, "items"> & { count?: number };

const CarouselDemo = ( { count = 14, ...props }: DemoProps ) => {
  const items = Array.from( { length: count }, ( _, i ) => (
    <PlaceholderItem key={i} label={`Item ${i + 1}`} />
  ) );

  return <Carousel {...props} items={items} />;
};

export const Default: Story = {
  render: args => <CarouselDemo {...args} />,
  args: {
    title: "Featured Species",
    description: "Species observed in your area this week.",
    url: "/taxa"
  }
};

export const Empty: Story = {
  render: args => <CarouselDemo {...args} count={0} />,
  args: { title: "Recent Observations", noContent: "No observations found." }
};
