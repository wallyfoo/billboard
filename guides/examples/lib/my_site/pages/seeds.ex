defmodule MySite.Pages.Seeds do
  @moduledoc """
  The home page's layout and its placeholder copy, written from code so
  a fresh database has them: `priv/repo/seeds.exs` runs `home/0`. Each
  run puts the same page back and publishes it.
  """

  # guide:home
  def home do
    Billboard.Pages.put_page(
      "/",
      [
        %{
          type: :hero,
          key: "home-hero",
          content: %{
            variant: :media_right,
            eyebrow: "Psychology in the city",
            heading: "Talking helps",
            lede: "Assessments and therapy for adults, in person and online.",
            actions: [
              %{label: "Book a first session", path: "/contact", style: :primary},
              %{label: "How it works", path: "/about", style: :secondary}
            ],
            photo: %{label: "The consulting room"}
          }
        },
        %{
          type: :points,
          key: "home-points",
          anchor: "how-we-work",
          content: %{
            head: %{eyebrow: "How we work", heading: "Three things to know"},
            columns: 3,
            points: [
              %{title: "Unhurried", body: "Fifty minutes, every time."},
              %{title: "Plain words", body: "No jargon in the room or in the report."},
              %{
                title: "Near you",
                body: "Ten minutes from the station.",
                link: %{label: "Find us", path: "/contact", style: :text}
              }
            ]
          }
        },
        %{
          type: :band,
          key: "home-band",
          surface: "band",
          content: %{
            variant: :heading,
            eyebrow: "First sessions",
            heading: "A first talk costs nothing",
            body: "Twenty minutes on the phone, to see whether we suit you.",
            action: %{label: "Ask for a call", path: "/contact", style: :secondary}
          }
        },
        %{
          type: :text_media,
          key: "home-about",
          content: %{
            variant: :media_left,
            head: %{heading: "Who you'll see"},
            body: "Every psychologist here is registered and supervised.",
            photo: %{label: "The team, outside"}
          }
        }
      ],
      authorize?: false
    )
  end

  # guide:end
end
