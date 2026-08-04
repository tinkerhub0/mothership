import { defineCollection, z } from "astro:content";
import { glob } from "astro/loaders";

const blog = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/blog" }),
  schema: z.object({
    title: z.string(),
    date: z.string(),
    summary: z.string(),
    author: z.string(),
  }),
});

// ship log — house changelog. one markdown file per entry under content/log/
const log = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/log" }),
  schema: z.object({
    title: z.string(),
    date: z.string(), // YYYY-MM-DD
    kind: z.enum(["ship", "member", "ops", "site"]).default("ship"),
    summary: z.string(),
    author: z.string().default("house"),
  }),
});

// crew — people who keep the house standing (not every member VM)
const crew = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/crew" }),
  schema: z.object({
    name: z.string(),
    role: z.string(),
    order: z.number().default(100),
    links: z
      .array(
        z.object({
          label: z.string(),
          href: z.string(),
        }),
      )
      .default([]),
  }),
});

export const collections = { blog, log, crew };
