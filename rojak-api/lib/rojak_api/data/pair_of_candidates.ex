defmodule RojakAPI.Data.PairOfCandidates do
  import Ecto.Query

  alias RojakAPI.Repo
  alias RojakAPI.Data.Schemas.{
    PairOfCandidates,
    Media
  }

  def fetch(%{embed: embed}) do
    PairOfCandidates
    |> fetch_embed(embed)
    |> Repo.all
  end

  def fetch_one(%{id: id, embed: embed}) do
    PairOfCandidates
    |> fetch_embed(embed)
    |> Repo.get!(id)
  end

  def fetch_media_sentiments(%{id: id, limit: limit, offset: offset}) do
    pairing = Repo.get! PairOfCandidates, id

    query = from m in Media,
      left_join: cagub_sentiments in fragment("""
        SELECT
          s.candidate_id,
          n.media_id,
          COUNT(CASE WHEN s.name like 'pro%' THEN 1 END) positive,
          COUNT(CASE WHEN s.name like 'net%' THEN 1 END) neutral,
          COUNT(CASE WHEN s.name like 'con%' THEN 1 END) negative
        FROM news_sentiment ns
        JOIN news n ON ns.news_id = n.id
        JOIN sentiment s ON ns.sentiment_id = s.id
        GROUP BY s.candidate_id, n.media_id
        """), on: cagub_sentiments.media_id == m.id and cagub_sentiments.candidate_id == ^pairing.cagub_id,
      left_join: cawagub_sentiments in fragment("""
        SELECT
          s.candidate_id,
          n.media_id,
          COUNT(CASE WHEN s.name like 'pro%' THEN 1 END) positive,
          COUNT(CASE WHEN s.name like 'net%' THEN 1 END) neutral,
          COUNT(CASE WHEN s.name like 'con%' THEN 1 END) negative
        FROM news_sentiment ns
        JOIN news n ON ns.news_id = n.id
        JOIN sentiment s ON ns.sentiment_id = s.id
        GROUP BY s.candidate_id, n.media_id
        """), on: cawagub_sentiments.media_id == m.id and cawagub_sentiments.candidate_id == ^pairing.cawagub_id,
      limit: ^limit,
      offset: ^offset,
      select: %{m |
        sentiments: %{
          cagub: %{
            positive: cagub_sentiments.positive,
            neutral: cagub_sentiments.neutral,
            negative: cagub_sentiments.negative
          },
          cawagub: %{
            positive: cawagub_sentiments.positive,
            neutral: cawagub_sentiments.neutral,
            negative: cawagub_sentiments.negative
          }
        }
      }

    query
    |> Repo.all
  end

  defp fetch_embed(query, embed) when is_nil(embed), do: query
  defp fetch_embed(query, embed) do
    query
    |> fetch_candidates(Enum.member?(embed, "candidates"))
    |> fetch_sentiments(Enum.member?(embed, "sentiments"))
    |> select_embed_fields(embed)
  end

  defp select_embed_fields(query, embed) do
    case [Enum.member?(embed, "candidates"), Enum.member?(embed, "sentiments")] do
      [true, true] ->
        from [q, cagub, cawagub, cagub_sentiments, cawagub_sentiments] in query,
          select: %{q |
            candidates: %{cagub: cagub, cawagub: cawagub},
            sentiments: %{
              cagub: %{
                positive: cagub_sentiments.positive,
                neutral: cagub_sentiments.neutral,
                negative: cagub_sentiments.negative,
              },
              cawagub: %{
                positive: cawagub_sentiments.positive,
                neutral: cawagub_sentiments.neutral,
                negative: cawagub_sentiments.negative,
              },
            }
          }
      [true, _] ->
        from [q, cagub, cawagub] in query,
          select: %{q | candidates: %{cagub: cagub, cawagub: cawagub}}
      [_, true] ->
        from [q, cagub_sentiments, cawagub_sentiments] in query,
          select: %{q |
            sentiments: %{
              cagub: %{
                positive: cagub_sentiments.positive,
                neutral: cagub_sentiments.neutral,
                negative: cagub_sentiments.negative,
              },
              cawagub: %{
                positive: cawagub_sentiments.positive,
                neutral: cawagub_sentiments.neutral,
                negative: cawagub_sentiments.negative,
              },
            }
          }
      _ ->
        query
    end
  end

  defp fetch_candidates(query, embed?) when not embed?, do: query
  defp fetch_candidates(query, _) do
    from q in query,
      left_join: cagub in assoc(q, :cagub),
      left_join: cawagub in assoc(q, :cawagub)
  end

  defp fetch_sentiments(query, embed?) when not embed?, do: query
  defp fetch_sentiments(query, _) do
    from q in query,
      left_join: cagub_sentiments in fragment("""
        SELECT
          s.candidate_id,
          COUNT(CASE WHEN s.name like 'pro%' THEN 1 END) positive,
          COUNT(CASE WHEN s.name like 'net%' THEN 1 END) neutral,
          COUNT(CASE WHEN s.name like 'con%' THEN 1 END) negative
        FROM news_sentiment ns
        JOIN sentiment s ON ns.sentiment_id = s.id
        GROUP BY s.candidate_id
        """), on: cagub_sentiments.candidate_id == q.cagub_id,
      left_join: cawagub_sentiments in fragment("""
        SELECT
          s.candidate_id,
          COUNT(CASE WHEN s.name like 'pro%' THEN 1 END) positive,
          COUNT(CASE WHEN s.name like 'net%' THEN 1 END) neutral,
          COUNT(CASE WHEN s.name like 'con%' THEN 1 END) negative
        FROM news_sentiment ns
        JOIN sentiment s ON ns.sentiment_id = s.id
        GROUP BY s.candidate_id
        """), on: cawagub_sentiments.candidate_id == q.cawagub_id
  end

end
