export default {
  props: {
    title: String
  },
  template: `
  <div class="
    z-[1000] 
    bg-[#212126] 
    border 
    rounded 
    min-w-96 
    min-h-[300px] 
    max-h-[600px] 
    overflow-y-auto 
    p-2 
    fixed 
    inset-x-1/2 
    -translate-x-1/2 
    inset-y-1/2 
    -translate-y-1/2
  ">
    <div class="flex flex-row justify-between items-center">
      <button @click="$emit('close')" class="bg-none border-none">
        x
      </button>
      <h1 class="h1 font-bold">{{ title }}</h1>
      <div></div>
    </div>
    <div class="mt-2">
      <slot/>
    </div>
  </div>
  `
}
